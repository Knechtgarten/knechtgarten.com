-- Pendenzen: eigene Farbe pro Liste (null = Farbe der Pendenzenart)
alter table pendenz_liste add column if not exists farbe text null;
