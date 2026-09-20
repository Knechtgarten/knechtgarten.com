-- ============================================================================
-- Mail-Assistent: Zweites Zusatzinfo-Feld fuer die Kundenanfragen-Info-
-- Spalte - erscheint zwischen dem eigenen Standort (Knechtgarten) und der
-- Partnerbetriebe-Liste, waehrend das bestehende partner_hinweistext-Feld
-- weiterhin ganz unten erscheint.
-- ============================================================================

alter table mailassistent_distanzlogik_meta add column if not exists distanz_erklaerung text;
