-- ============================================================================
-- Mail-Assistent: Absage-Text fuer "zu weit entfernt" - analog zum
-- Weiterleitungstext je Partnerbetrieb, aber fuer Knechtgarten selbst.
-- Erscheint in Gmail als kompakter "Absagen"-Button direkt bei der eigenen
-- Distanz-Zeile.
-- ============================================================================

alter table mailassistent_distanzlogik_meta add column if not exists absage_text text;
