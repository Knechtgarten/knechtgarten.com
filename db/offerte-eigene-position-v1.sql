-- ============================================================================
-- Offertentool 2027 - "Eigene Position" fuer den Offertentyp "Allgemein"
-- (Tagessatz-Modell): eine einmalige Zusatzposition nur fuer eine bestimmte
-- Offerte (kein dauerhafter Katalog-Eintrag in Tool B).
--
-- Struktur analog zu einem echten Tagessatz-Arbeitsschritt (Maschine/
-- Baumaschine/Lieferwagen als CHF-Betraege fuer diese Position, Material als
-- eine oder mehrere frei erfassbare Zeilen).
-- ============================================================================

create table offerte_eigene_position (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  bezeichnung text not null,
  beschreibung text null,
  maschine_chf numeric not null default 0,
  baumaschine_chf numeric not null default 0,
  lieferwagen_chf numeric not null default 0,
  reihenfolge int not null default 0
);

create table offerte_eigene_position_material (
  id uuid primary key default gen_random_uuid(),
  eigene_position_id uuid not null references offerte_eigene_position(id) on delete cascade,
  bezeichnung text not null,
  menge numeric not null default 1,
  einheit text null,
  preis numeric not null default 0,
  reihenfolge int not null default 0
);

-- RLS: gleiches Muster wie andere Offerten-Daten (kunde/offerte/teilflaeche...)
-- - voller Zugriff fuer jeden eingeloggten, zugewiesenen Benutzer.
alter table offerte_eigene_position enable row level security;
alter table offerte_eigene_position_material enable row level security;
create policy offerte_eigene_position_voller_zugriff on offerte_eigene_position
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
create policy offerte_eigene_position_material_voller_zugriff on offerte_eigene_position_material
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
