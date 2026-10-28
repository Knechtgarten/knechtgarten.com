-- Kies-/Betonwerke in EINER Liste (statt kieswerk_kies + kieswerk_beton), Nutzerentscheid 2026-10-28.
-- Preis pro m³ = Preisliste des Werks (folgt, Etappe 2) oder Formel: Grundpreis + km-Preis * km (Einkaufspreis), dann Marge.
-- Formelwerte aus Stichproben Heimberg/Stucki: kostendeckend bei allen 23 Stichproben (siehe Chat 2026-10-28).
-- Die alten Tabellen kieswerk_kies/kieswerk_beton bleiben unveraendert bestehen, werden aber nicht mehr verwendet.
create table if not exists transport_werk (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null default '',
  reihenfolge integer not null default 0,
  erstellt_am timestamptz not null default now(),
  liefert_kies boolean not null default true,
  liefert_beton boolean not null default true,
  marge_pct numeric not null default 20,
  grundpreis_m3 numeric not null default 0,
  km_preis_m3 numeric not null default 0,
  mindestmenge_kies numeric,
  mindestmenge_beton numeric,
  listentyp text check (listentyp in ('ort', 'distanz')),
  liste_jahr integer,
  liste_gueltig_ab date,
  liste_orte integer,
  geprueft_ok boolean,
  geprueft_fehler text
);

alter table transport_werk enable row level security;
create policy transport_werk_lesen on transport_werk for select using (ist_eingeloggter_benutzer());
create policy transport_werk_admin_schreibt on transport_werk for all using (ist_admin()) with check (ist_admin());

insert into transport_werk (name, adresse, reihenfolge, liefert_kies, liefert_beton, marge_pct, grundpreis_m3, km_preis_m3, mindestmenge_kies, mindestmenge_beton, geprueft_ok)
values
  ('Heimberg',      'Gurnigelstrasse 50, 3627 Heimberg', 1, true, true, 20, 7.04, 1.71, 8, 6, true),
  ('Stucki',        'Gridenbühl 161, 3673 Linden',       2, true, true, 20, 7.93, 1.33, 8, 6, true),
  ('Däpp Oppligen', '3629 Oppligen',                     3, true, true, 20, 7.83, 1.63, 8, 6, null),
  ('Alluvia Bern',  '',                                  4, true, true, 20, 7.83, 1.63, 8, 6, null);

-- Gewaehltes Werk pro Offerte (null = automatisch das guenstigste)
alter table offerte
  add column if not exists transport_werk_kies_id uuid references transport_werk(id) on delete set null,
  add column if not exists transport_werk_beton_id uuid references transport_werk(id) on delete set null;
