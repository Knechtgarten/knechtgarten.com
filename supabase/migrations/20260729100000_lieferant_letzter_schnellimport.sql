-- ============================================================================
-- Offertentool 2027 - Eigener Zeitstempel fuer den letzten Schnellimport pro
-- Lieferant, getrennt vom bestehenden letzter_abgleich_zeitpunkt (der nur vom
-- grossen Abgleich-Tool - Crawling/Google Sheet/PDF/manuell - geschrieben
-- wird). So bleiben beide Wege in der Lieferanten-Tabelle getrennt sichtbar,
-- ein kleiner Schnellimport ueberschreibt nicht mehr den letzten echten
-- Abgleich-Zeitpunkt und umgekehrt.
-- ============================================================================

alter table lieferant_datenabgleich add column letzter_schnellimport_zeitpunkt timestamptz null;
