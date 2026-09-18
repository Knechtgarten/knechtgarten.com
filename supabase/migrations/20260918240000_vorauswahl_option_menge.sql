-- Mengenoptionen (z.B. "4-6 Leitungen" mit einer Anzahl daneben) brauchen in
-- einer Vorauswahl auch eine vorausgefuellte Menge, nicht nur "Option an/aus".
alter table vorauswahl_option add column menge numeric null;
