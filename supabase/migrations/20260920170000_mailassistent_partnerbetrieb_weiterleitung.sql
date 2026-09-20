-- ============================================================================
-- Mail-Assistent: Weiterleitungstext direkt am Partnerbetrieb statt als
-- eigene, freistehende Antwort-Vorlage im Kundenanfragen-Topf. Ist 1:1 an
-- den Partnerbetrieb gebunden (kein Sinn ohne ihn) - darum eigene Spalte
-- statt eigener mailassistent_vorlage-Zeile, und in der Admin-Oberflaeche
-- nicht loeschbar, nur bearbeitbar.
-- ============================================================================

alter table mailassistent_partnerbetrieb add column if not exists weiterleitung_text text;
