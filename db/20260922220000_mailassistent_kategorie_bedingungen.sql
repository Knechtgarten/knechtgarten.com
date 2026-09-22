-- ============================================================================
-- Mail-Assistent: Kategorie/Unterkategorie bekommen eigene "Anwenden bei" /
-- "Nicht anwenden bei"-Felder, analog zu den Vorlagen - damit sich Stefan
-- durchfragen kann, wo eine Mail eigentlich hingehoert, statt nur den
-- Titel als einzigen Anhaltspunkt zu haben.
-- ============================================================================

alter table mailassistent_kategorie add column if not exists anwenden_bei text;
alter table mailassistent_kategorie add column if not exists nicht_anwenden_bei text;
alter table mailassistent_unterkategorie add column if not exists anwenden_bei text;
alter table mailassistent_unterkategorie add column if not exists nicht_anwenden_bei text;
