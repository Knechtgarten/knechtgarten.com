-- ============================================================================
-- Offertentool 2027 - Lieferwagentransport (Kieswerk/Betonwerk, Deponie,
-- Magazin): zweiter, alternativer Preis-Artikel nach km statt nur Std.
-- Welcher der beiden gilt, entscheidet der globale Km/Std-Schalter pro
-- Offerte (lieferwagenModus in Tool A) - genau derselbe Schalter wie bei der
-- Hin- und Rueckfahrt zur Baustelle oben in der Offerte.
-- ============================================================================

alter table sonderposition_typ add column lieferwagen_km_artikel_id uuid null references artikel(id) on delete restrict;
