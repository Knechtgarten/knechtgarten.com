-- Neue Spaltenart "Auswahl" für Tabellenspalten: Dropdown mit Text und Zahl, z.B. [{"text":"einseitig","wert":1},{"text":"beidseitig","wert":2}].
-- Gerechnet wird mit der Zahl (wert), gespeichert wie jede andere Eingabe.
alter table eingabefeld_tabelle_spalte add column if not exists auswahl_werte jsonb;
