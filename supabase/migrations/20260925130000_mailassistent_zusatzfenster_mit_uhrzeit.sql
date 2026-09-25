-- Mail-Assistent: "Termin"-Funktion (Zusatzfenster Typ Kalender) bekommt eine
-- Einstellung "Mit Uhrzeit" - steuert, ob beim manuellen "Ein Datum
-- eintragen" (Termin-Button direkt im Text) ein reines Datumsfeld oder ein
-- Datum-mit-Uhrzeit-Feld angezeigt wird. Aus dem Kalender uebernommene
-- Termine haben ohnehin schon eine Uhrzeit, betrifft also nur die manuelle
-- Eingabe.
alter table mailassistent_zusatzfenster
  add column if not exists mit_uhrzeit boolean not null default false;
