-- Pendenzen: eigene Breite pro Liste (nur in der freien Anordnung, null = Standard 320 px)
alter table pendenz_liste add column if not exists breite int null check (breite between 200 and 1200);
