-- ============================================================================
-- Offertentool 2027 - Markiert pro Lieferant, ob ein Datenabgleich ueber
-- Webshop (Crawling) fuer diesen Lieferanten tatsaechlich eingerichtet ist.
-- Solange das nicht der Fall ist, zeigt die Abgleich-Seite beim Versuch,
-- ueber Webshop abzugleichen, eine klare Fehlermeldung statt eines Fake-
-- Ergebnisses.
-- ============================================================================

alter table lieferant_datenabgleich add column webshop_abgleich_eingerichtet boolean not null default false;
