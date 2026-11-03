-- Etappe 2: Easybill-Angebote mit unseren Offerten verbinden, «zugesagt» = Status 'bestaetigt'.
-- Läuft am Ende jedes Easybill-Abgleichs (Edge Function easybill-abgleich ruft easybill_verknuepfen() auf).

alter table easybill_dokument add column if not exists offerte_id uuid references offerte(id) on delete set null;
alter table offerte add column if not exists auftrag_easybill_id bigint;   -- Auftragsbestätigung (easybill_dokument)
alter table offerte add column if not exists auftrag_nummer text;
alter table offerte add column if not exists bestaetigt_am date;

create or replace function easybill_verknuepfen() returns jsonb
language plpgsql security definer set search_path = public as $$
declare n_angebote int; n_auftrag int; n_bestaetigt int;
begin
  -- 1) Easybill-Angebot ↔ exportierte Offerte (gleiche Easybill-ID oder Nummer)
  update easybill_dokument d set offerte_id = o.id
  from offerte o
  where d.typ = 'OFFER' and d.offerte_id is distinct from o.id
    and (d.easybill_id = o.easybill_document_id or (o.easybill_document_number is not null and d.nummer = o.easybill_document_number));
  get diagnostics n_angebote = row_count;

  -- 2) Offerte steht in einer Auftragsbestätigung: AB merken (neueste zuerst)
  with treffer as (
    select distinct on (o.id) o.id, ab.easybill_id, ab.nummer, ab.datum
    from offerte o
    join easybill_dokument ab on ab.typ = 'ORDER' and o.easybill_document_number = any(ab.angebot_nummern)
    where o.easybill_document_number is not null
    order by o.id, ab.datum desc nulls last
  )
  update offerte o set auftrag_easybill_id = t.easybill_id, auftrag_nummer = t.nummer
  from treffer t where o.id = t.id and o.auftrag_easybill_id is distinct from t.easybill_id;
  get diagnostics n_auftrag = row_count;

  -- 3) offene Offerten mit AB = bestätigt (zugesagt); «abgelehnt» bleibt unangetastet
  update offerte o set status = 'bestaetigt', bestaetigt_am = coalesce(o.bestaetigt_am, ab.datum)
  from easybill_dokument ab
  where ab.easybill_id = o.auftrag_easybill_id and coalesce(o.status, 'offen') = 'offen';
  get diagnostics n_bestaetigt = row_count;

  return jsonb_build_object('angebote_verknuepft', n_angebote, 'offerten_mit_ab', n_auftrag, 'offerten_bestaetigt', n_bestaetigt);
end $$;
revoke all on function easybill_verknuepfen() from public, anon, authenticated;
