-- ============================================================================
-- Offertentool 2027 - Lieferant archivieren statt zwingend loeschen.
--
-- Statt einen Lieferanten (und all seine Artikel) endgueltig zu loeschen -
-- was durch Fremdschluessel aus Ressourcenzeilen/Preisfindung/Offerten
-- ohnehin oft blockiert waere - kann er hier archiviert werden. Archivierte
-- Lieferanten und ihre Artikel verschwinden aus allen Auswahl-Feldern
-- (Artikel-Picker), bleiben aber im Artikelstamm/in der Lieferanten-Liste
-- sichtbar. Gleiches Muster wie offertentyp.papierkorb_am
-- (timestamptz null = aktiv, gesetzt = archiviert, seit wann).
-- ============================================================================

alter table lieferant add column archiviert_am timestamptz null;
