-- ============================================================================
-- Mail-Assistent: Die "Zusatzinfo" fuer die Info-Spalte im Kundenanfragen-
-- Popup ist EIN gemeinsamer Text fuer alle Kundenanfragen (erscheint ja
-- unabhaengig davon, welcher Topf getroffen hat, immer neben der gleichen
-- Distanz-Info) - gehoert darum nicht pro Topf in mailassistent_vorlage,
-- sondern eine Ebene hoeher als gemeinsame Einstellung. mailassistent_
-- distanzlogik_meta ist genau dafuer schon die passende Singleton-Tabelle
-- (frueher "wann_anwenden" fuer die alte Distanzlogik, jetzt nicht mehr
-- verwendet - die Zeile bleibt aber bestehen und bekommt hier ihre neue
-- Aufgabe).
-- ============================================================================

alter table mailassistent_distanzlogik_meta add column if not exists partner_hinweistext text;
