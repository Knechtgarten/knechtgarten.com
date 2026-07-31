-- ============================================================================
-- Offertentool 2027 - Margen-Logik pro Lieferant umgebaut: statt "hoeherer
-- von zwei Kandidaten gewinnt" (VP-Lieferant-Aufschlag vs. Minimum-Marge)
-- gibt es jetzt eine bewusste, exklusive Wahl pro Lieferant:
--
-- - vp_lieferant_gleich_vp_knecht = true:
--     VP Knecht = VP Lieferant x (1 + zuschlag_prozent / 100)
--     (zuschlag_prozent fasst Zoll/Fracht/Sonderzuschlag usw. zusammen)
-- - vp_lieferant_gleich_vp_knecht = false (Standard):
--     VP Knecht = EP Lieferant / (1 - minimum_marge_prozent / 100)
--     (minimum_marge_prozent bleibt die bestehende Spalte, jetzt exklusiv
--     statt als Untergrenze in einem Max-Vergleich verwendet)
--
-- zoll_fracht_prozent und sonderzuschlag_prozent waren bislang bei KEINEM
-- Lieferanten gesetzt (geprüft vor dieser Migration) - werden darum ohne
-- Datenmigration durch die eine neue Spalte zuschlag_prozent ersetzt.
-- ============================================================================

alter table lieferant_datenabgleich add column vp_lieferant_gleich_vp_knecht boolean not null default false;
alter table lieferant_datenabgleich add column zuschlag_prozent numeric null;
alter table lieferant_datenabgleich drop column zoll_fracht_prozent;
alter table lieferant_datenabgleich drop column sonderzuschlag_prozent;
