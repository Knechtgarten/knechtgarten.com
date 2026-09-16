-- ============================================================================
-- Mail-Assistent: Betreff-Feld fuer Verfassen-Vorlagen.
--
-- Bisher hatte eine Vorlage nur "titel" (interne Bezeichnung fuer den Chip in
-- der Erweiterung und zur Erkennung durch die KI) - der landete faelschlich
-- gar nicht im Betreff-Feld von Gmail. Jetzt gibt es ein eigenes, optionales
-- Betreff-Feld, das beim "In Mail uebernehmen" zusaetzlich ins Betreff-Feld
-- eingetragen wird (nur relevant beim Verfassen einer neuen Mail).
-- ============================================================================

alter table mailassistent_vorlage add column if not exists betreff text;
