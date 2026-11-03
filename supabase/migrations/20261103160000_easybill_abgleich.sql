-- Easybill-Abgleich (nur lesend): Kundenstamm + Auftragsbestätigungen (ORDER) und die Angebote (OFFER), auf die sie verweisen.
-- Geschrieben wird nur von der Edge Function easybill-abgleich (Service-Rolle), jede Nacht und auf Knopfdruck.
-- Grundlage für Bauprogramm (Einsatzplaner) und Dokumente beim Kunden.

create table if not exists easybill_dokument (
  easybill_id bigint primary key,
  typ text not null check (typ in ('ORDER', 'OFFER')),
  nummer text,
  titel text,
  datum date,
  kunde_easybill_id bigint,
  kunde_id uuid references kunde(id) on delete set null,
  betrag_netto numeric(12,2),
  text_prefix text,
  text text,                         -- ohne HTML
  positionen jsonb not null default '[]'::jsonb,  -- [{pos, typ, text, menge, einheit, nummer, betrag_netto}]
  angebot_nummern text[] not null default '{}',   -- nur ORDER: verwiesene Angebote
  geaendert_easybill timestamptz,
  abgeglichen_am timestamptz not null default now()
);
create index if not exists easybill_dokument_kunde on easybill_dokument (kunde_id, typ, datum desc);
create index if not exists easybill_dokument_nummer on easybill_dokument (typ, nummer);

create table if not exists easybill_abgleich (
  id bigint generated always as identity primary key,
  modus text not null,               -- 'nacht' | 'alles' | 'kunde'
  kunde_id uuid,
  gestartet timestamptz not null default now(),
  beendet timestamptz,
  kunden integer,
  dokumente integer,
  fehler text,
  ausgeloest_von uuid
);

alter table easybill_dokument enable row level security;
alter table easybill_abgleich enable row level security;
drop policy if exists easybill_dokument_lesen on easybill_dokument;
create policy easybill_dokument_lesen on easybill_dokument for select using (ist_eingeloggter_benutzer());
drop policy if exists easybill_abgleich_lesen on easybill_abgleich;
create policy easybill_abgleich_lesen on easybill_abgleich for select using (ist_eingeloggter_benutzer());
