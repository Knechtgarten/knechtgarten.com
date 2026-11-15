-- Offertentyp «KI»: Offerte im Gespräch erstellen (Chat links, Blatt rechts). Preise aus Artikelstamm/alten Offerten.
alter table public.offertentyp drop constraint if exists offertentyp_berechnungsmodell_check;
alter table public.offertentyp add constraint offertentyp_berechnungsmodell_check check (berechnungsmodell = any (array['formel','tagessatz','artikel','easy','ki']));
insert into public.offertentyp (name, berechnungsmodell, reihenfolge, ausgeblendet, icon_key)
select 'KI', 'ki', 5, false, 'funken' where not exists (select 1 from public.offertentyp where berechnungsmodell = 'ki');

-- Gesprächsverlauf pro Offerte (nur Text; die KI liest ihn bei jeder Nachricht neu)
create table if not exists public.offerte_ki_verlauf (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references public.offerte(id) on delete cascade,
  rolle text not null check (rolle in ('user','assistant')),
  text text not null,
  erstellt_am timestamptz not null default now(),
  erstellt_von uuid default auth.uid()
);
create index if not exists offerte_ki_verlauf_offerte_idx on public.offerte_ki_verlauf(offerte_id, erstellt_am);
alter table public.offerte_ki_verlauf enable row level security;
drop policy if exists offerte_ki_verlauf_alle on public.offerte_ki_verlauf;
create policy offerte_ki_verlauf_alle on public.offerte_ki_verlauf for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Zeilen, deren Preis die KI geschätzt hat (kein Artikel, keine alte Offerte) – zum Prüfen markiert
alter table public.offerte_eigene_zeile add column if not exists ki_geschaetzt boolean not null default false;
