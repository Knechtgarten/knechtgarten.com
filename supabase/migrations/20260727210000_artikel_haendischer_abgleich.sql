-- ============================================================================
-- Offertentool 2027 - Markierung "Händischer Abgleich" pro Artikel.
--
-- Manche Artikel lassen sich nicht zuverlaessig automatisch abgleichen (z.B.
-- beim Lieferanten nicht im Shop/PDF verfuegbar) und muessen darum von Hand
-- geprueft/angepasst werden (typischerweise einmal im Jahr). Bewusst ein
-- eigenes Feld statt Wiederverwendung von sync_offertentool/sync_webtool/
-- sync_easybill - jene beschreiben WOHIN ein Artikel synct, nicht WIE sein
-- Preis aktuell gehalten wird.
-- ============================================================================

alter table artikel add column haendischer_abgleich boolean not null default false;
