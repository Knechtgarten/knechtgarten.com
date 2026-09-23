-- Mail-Assistent: neue Tabelle fuer frei benannte Wissens-Bloecke (Titel +
-- Freitext) auf der Seite "Nachschlagewerk" (vormals "Firmendaten") - fuer
-- allgemeines Wissen, das nicht in Stammdaten/Mitarbeiter/Externe Kontakte
-- passt. Gleiches Muster wie mailassistent_faelle_abschnitt/
-- mailassistent_grundlogik_abschnitt/mailassistent_schreibstil_abschnitt.
create table if not exists mailassistent_wissen_abschnitt (
  id uuid primary key default gen_random_uuid(),
  titel text not null default 'Neuer Block',
  inhalt text,
  reihenfolge integer not null default 0
);
