-- ============================================================================
-- Offertentool 2027 - Ressourcenzeile: Reihenfolge fuer Drag & Drop.
--
-- Die Artikel-/Sonderpositions-Zeilen innerhalb eines Teilschritts (Tabelle
-- Typ/Artikel/Menge in Tool B) hatten bisher keine eigene Sortierreihenfolge
-- - sie kamen einfach in DB-Reihenfolge zurueck. Jetzt wie bei
-- Arbeitsschritt/Teilschritt/Eingabefeld/Term per Drag & Drop sortierbar.
-- ============================================================================

alter table ressourcenzeile add column if not exists reihenfolge integer not null default 0;
