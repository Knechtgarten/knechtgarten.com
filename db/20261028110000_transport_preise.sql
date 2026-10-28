-- Etappe 2 Kies-/Betonwerke (2026-10-28): Preislisten der Werke + Alluvia mit zwei Standorten + Lieferwagen-Abholorte getrennt.
--  * transport_preis: Ortsliste eines Werks (Heimberg mit PLZ, Stucki/Daepp nur Gemeinde/Ort). Mehrere Zeilen pro Ort moeglich,
--    in der Offerte gilt der teuerste Preis.
--  * transport_distanzstufe: Distanzliste (Alluvia: Preis je km-Stufe).
--  * lieferwagen_holt: nur diese Werke zaehlen fuer den EIGENEN Lieferwagentransport (Fremdtransport-Preislisten haben dort keinen Einfluss).
create table if not exists transport_preis (
  id uuid primary key default gen_random_uuid(),
  werk_id uuid not null references transport_werk(id) on delete cascade,
  plz text,
  gemeinde text,
  ort text,
  kies_m3 numeric,
  beton_m3 numeric,
  zone text
);
create index if not exists transport_preis_werk_plz on transport_preis (werk_id, plz);
create index if not exists transport_preis_werk_ort on transport_preis (werk_id);

create table if not exists transport_distanzstufe (
  id uuid primary key default gen_random_uuid(),
  werk_id uuid not null references transport_werk(id) on delete cascade,
  bis_km numeric not null,
  kies_m3 numeric,
  beton_m3 numeric
);
create index if not exists transport_distanzstufe_werk on transport_distanzstufe (werk_id, bis_km);

alter table transport_preis enable row level security;
alter table transport_distanzstufe enable row level security;
create policy transport_preis_lesen on transport_preis for select using (ist_eingeloggter_benutzer());
create policy transport_preis_admin_schreibt on transport_preis for all using (ist_admin()) with check (ist_admin());
create policy transport_distanzstufe_lesen on transport_distanzstufe for select using (ist_eingeloggter_benutzer());
create policy transport_distanzstufe_admin_schreibt on transport_distanzstufe for all using (ist_admin()) with check (ist_admin());

alter table transport_werk add column if not exists lieferwagen_holt boolean not null default false;
update transport_werk set lieferwagen_holt = true where name in ('Heimberg', 'Stucki');

-- Alluvia: Kies in Oberwangen, Beton in Bern-Bethlehem (zwei Standorte = zwei Zeilen, je nur ein Haken)
update transport_werk set name = 'Alluvia Bern-Bethlehem', adresse = 'Murtenstrasse 200, 3027 Bern', liefert_kies = false, liefert_beton = true, reihenfolge = 5
 where name = 'Alluvia Bern';
insert into transport_werk (name, adresse, reihenfolge, liefert_kies, liefert_beton, marge_pct, grundpreis_m3, km_preis_m3, mindestmenge_kies, mindestmenge_beton)
select 'Alluvia Oberwangen', 'Steinhohle 25, 3173 Oberwangen', 4, true, false, 20, 7.83, 1.63, 8, 6
 where not exists (select 1 from transport_werk where name = 'Alluvia Oberwangen');
