-- ============================================================================
-- Tabellen-Eingabefeld (eingabefeld_tabelle_spalte): optionaler Vorschlags-
-- wert fuer Eingabe-Spalten (nicht Berechnung) - erscheint im Konfigurator
-- (Tool A) automatisch vorausgefuellt bei jeder neuen Tabellenzeile, bleibt
-- dort aber weiterhin frei aenderbar. Gleiches Prinzip wie
-- eingabefeld.fixer_wert (Vorschlagswert einzelner Eingabefelder).
-- ============================================================================

alter table eingabefeld_tabelle_spalte add column vorschlagswert numeric null;
