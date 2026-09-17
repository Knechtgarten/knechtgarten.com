-- ============================================================================
-- Icon pro Offerten-Vorlage (offertentyp) - rein optisch, damit man in der
-- "Neue Offerte"-Auswahl und in Tool B auf einen Blick sieht, um welches
-- Thema es sich handelt (Blume fuer Bepflanzung, Lampe fuer Beleuchtung usw.).
-- Freier Text statt Enum, weil das Icon-Set rein clientseitig (in tool-b und
-- tool-start) gepflegt wird - bekannte Icon-Keys siehe OFFERTENTYP_ICONS dort.
-- Unbekannter/leerer Wert -> kein Icon, nur der Name (Fallback).
-- ============================================================================

alter table offertentyp add column icon_key text null;
