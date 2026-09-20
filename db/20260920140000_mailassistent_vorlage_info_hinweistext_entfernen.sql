-- ============================================================================
-- Mail-Assistent: info_hinweistext auf mailassistent_vorlage wieder entfernen.
-- Kundenanfragen wurden nochmals vereinfacht - es gibt keinen "Topf" mehr,
-- jede Antwort-Vorlage ist eine ganz normale mailassistent_vorlage-Zeile
-- (richtung='kundenanfrage', typ='einfach'). Der Zusatzinfo-Text fuer die
-- Info-Spalte gilt fuer alle gemeinsam und lebt in
-- mailassistent_distanzlogik_meta.partner_hinweistext - die Spalte hier
-- wurde nie mit echten Daten befuellt und wird nicht mehr gebraucht.
-- ============================================================================

alter table mailassistent_vorlage drop column if exists info_hinweistext;
