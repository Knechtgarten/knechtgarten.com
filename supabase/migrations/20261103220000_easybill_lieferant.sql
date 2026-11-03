-- Kontakte: Lieferanten aus Easybill (nur lesend geholt) + Verbindung zu unserer Lieferantenliste (Tabelle lieferant).
create table if not exists public.easybill_lieferant (
  easybill_id bigint primary key,
  nummer text,
  name text,
  firma text,
  vorname text,
  nachname text,
  strasse text,
  plz text,
  ort text,
  land text,
  kontaktdaten jsonb,
  archiviert boolean not null default false,
  lieferant_id uuid references public.lieferant(id) on delete set null,
  zuordnung text check (zuordnung in ('verbunden', 'vorschlag', 'bestaetigt', 'keine')),
  abgeglichen_am timestamptz not null default now()
);
alter table public.easybill_lieferant enable row level security;
drop policy if exists easybill_lieferant_lesen on public.easybill_lieferant;
create policy easybill_lieferant_lesen on public.easybill_lieferant for select using (ist_eingeloggter_benutzer());
-- Zuordnung bestätigen/ändern dürfen nur Admins (wie die Lieferantenliste); sonst schreibt nur der Abgleich (Service-Rolle)
drop policy if exists easybill_lieferant_admin on public.easybill_lieferant;
create policy easybill_lieferant_admin on public.easybill_lieferant for update using (ist_admin()) with check (ist_admin());

-- Zuordnung nach jedem Abgleich: 1) gleiche easybill_id = verbunden; 2) sonst Namensvorschlag (nur ohne Bestätigung/Ablehnung)
create or replace function public.easybill_lieferanten_zuordnen()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v int; s int;
begin
  update easybill_lieferant e set lieferant_id = l.id, zuordnung = 'verbunden'
  from lieferant l where l.easybill_id = e.easybill_id and (e.zuordnung is distinct from 'verbunden' or e.lieferant_id is distinct from l.id);
  get diagnostics v = row_count;
  update easybill_lieferant e set lieferant_id = x.id, zuordnung = 'vorschlag'
  from (
    select distinct on (e2.easybill_id) e2.easybill_id, l.id
    from easybill_lieferant e2 join lieferant l on l.easybill_id is null and l.archiviert_am is null
      and length(l.name) >= 4
      and (lower(coalesce(e2.firma, e2.name)) like '%' || lower(l.name) || '%' or lower(l.name) like '%' || lower(coalesce(e2.firma, e2.name)) || '%')
    where e2.zuordnung is null
    order by e2.easybill_id, length(l.name) desc
  ) x
  where e.easybill_id = x.easybill_id;
  get diagnostics s = row_count;
  return jsonb_build_object('lieferanten_verbunden', v, 'lieferanten_vorschlaege', s);
end $$;
revoke execute on function public.easybill_lieferanten_zuordnen() from public, anon, authenticated;
