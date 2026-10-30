-- Optionsgruppen (Nutzerwunsch 2026-10-30): mehrere Optionen eines Auswahlfelds werden in Tool B ueber einen Balken
-- zusammengefasst und erscheinen in Tool A als EIN Button mit Dropdown. Rein darstellend, die Rechenlogik bleibt gleich.
-- Gruppe = gleiche optionsgruppe_id innerhalb eines Auswahlfelds; der Name steht (denormalisiert) an jeder Option der Gruppe.
alter table auswahloption add column if not exists optionsgruppe_id uuid;
alter table auswahloption add column if not exists optionsgruppe_name text;
