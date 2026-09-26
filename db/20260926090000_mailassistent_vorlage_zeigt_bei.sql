-- Mail-Assistent: Verfassen-Vorlagen koennen jetzt unabhaengig voneinander
-- fuer "Verfassen" und/oder als Schnellauswahl-Button beim "Antworten"
-- freigegeben werden (zwei separate Haken in der Verwaltung). Default so
-- gewaehlt, dass sich fuer bestehende Vorlagen nichts aendert: weiterhin
-- ueberall beim Verfassen sichtbar, aber noch nirgends beim Antworten -
-- muss dort bewusst pro Vorlage aktiviert werden.
alter table mailassistent_vorlage
  add column if not exists zeigt_bei_verfassen boolean not null default true,
  add column if not exists zeigt_bei_antworten boolean not null default false;
