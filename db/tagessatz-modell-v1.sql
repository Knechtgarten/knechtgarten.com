-- ============================================================================
-- Offertentool 2027 - Tagessatz-Modell fuer Offertentyp "Allgemein"
-- Zweite Berechnungslogik neben dem Formel-Modell (Pool/Holzdeck): keine
-- Geometrie-Formel, sondern ein hinterlegter Tagessatz (Material/Maschine/
-- Baumaschine/Lieferwagen pro Tag). Der Mitarbeiter schaetzt in Tool A nur
-- die Anzahl Tage pro Arbeitsschritt.
-- Bewusst NICHT in diesem Schritt: "Eigene Position" (freie Zusatzpositionen),
-- editierbarer Tagessatz direkt in Tool A - kommt spaeter, falls gewuenscht.
-- ============================================================================

-- Arbeitsschritt um Tagessatz-Felder erweitern (nur genutzt, wenn der
-- uebergeordnete Offertentyp berechnungsmodell='tagessatz' hat).
alter table arbeitsschritt add column gruppe text;
alter table arbeitsschritt add column beschreibung text;
alter table arbeitsschritt add column tagessatz_material numeric;
alter table arbeitsschritt add column tagessatz_maschine numeric;
alter table arbeitsschritt add column tagessatz_baumaschine numeric;
alter table arbeitsschritt add column tagessatz_lieferwagen numeric;

-- Instanzdaten: wie viele Tage wurden fuer diesen Arbeitsschritt in dieser
-- Offerte geschaetzt.
create table offerte_arbeitsschritt_tage (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  arbeitsschritt_id uuid not null references arbeitsschritt(id) on delete restrict,
  anzahl_tage numeric not null default 0,
  unique (offerte_id, arbeitsschritt_id)
);

alter table offerte_arbeitsschritt_tage enable row level security;
create policy offerte_arbeitsschritt_tage_voller_zugriff on offerte_arbeitsschritt_tage
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- ----------------------------------------------------------------------------
-- Pilot-Daten: Offertentyp "Allgemein" + ein paar Beispiel-Arbeitsschritte
-- ----------------------------------------------------------------------------
do $$
declare
  v_offertentyp_id uuid;
begin
  insert into offertentyp (name, berechnungsmodell, reihenfolge)
  values ('Allgemein', 'tagessatz', 2)
  returning id into v_offertentyp_id;

  insert into arbeitsschritt (offertentyp_id, name, gruppe, beschreibung, reihenfolge,
    tagessatz_material, tagessatz_maschine, tagessatz_baumaschine, tagessatz_lieferwagen) values
  (v_offertentyp_id, 'Baustelle einrichten', 'Installation, Entsorgung, Erdarbeiten',
    'Baustelleneinrichtung inkl. Absperrung und Zufahrt.', 1, 40.00, 0.00, 0.00, 0.50),
  (v_offertentyp_id, 'Ausstecken und ausmessen', 'Installation, Entsorgung, Erdarbeiten',
    'Ausstecken der Anlage gemaess Planvorgabe.', 2, 0.00, 0.00, 0.00, 0.00),
  (v_offertentyp_id, 'Rodung von Sträuchern und Gehölzen', 'Installation, Entsorgung, Erdarbeiten',
    'Fachgerechte Rodung von Sträuchern und Gehölzen inkl. Abtransport.', 3, 160.00, 76.00, 0.00, 0.50),
  (v_offertentyp_id, 'Grasnarbe abtragen und entsorgen', 'Fundationen, Hartflächen, Natursteine',
    'Grasnarbe abtragen, Erdmaterial fachgerecht entsorgen.', 4, 90.00, 45.00, 0.00, 0.30),
  (v_offertentyp_id, 'Kies für Fundationen einbauen', 'Fundationen, Hartflächen, Natursteine',
    'Kiesbett einbauen und verdichten fuer Fundation.', 5, 220.00, 60.00, 20.00, 0.80);
end $$;
