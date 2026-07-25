-- ============================================================================
-- Offertentool 2027 - "Offerten laut Artikeln": pro Offerte gewaehlte Artikel,
-- gruppiert in die vier fixen Zwischentitel Personalaufwand/Maschinenaufwand/
-- Logistikaufwand/Materialaufwand.
--
-- bezeichnung/einheit/preis sind ein Snapshot bei Auswahl (aus artikel.
-- vp_knecht), danach frei editierbar - spaetere Preisaenderungen im
-- Artikelstamm wirken sich nicht rueckwirkend auf bestehende Offerten aus.
-- ============================================================================

create table offerte_artikel_position (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  kategorie text not null check (kategorie in ('personal','maschine','logistik','material')),
  artikel_id uuid not null references artikel(id) on delete restrict,
  bezeichnung text not null,
  einheit text null,
  menge numeric not null default 1,
  preis numeric not null default 0,
  reihenfolge int not null default 0
);

alter table offerte_artikel_position enable row level security;
create policy offerte_artikel_position_voller_zugriff on offerte_artikel_position
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
