-- ============================================================================
-- Offertentool 2027 - Papierkorb fuer Offerten-Vorlagen (Offertentyp).
--
-- Bisher war "Loeschen" ein sofortiges, endgueltiges Entfernen - das schlug
-- fuer Formel-Typen ausserdem an einem fehlenden ON DELETE CASCADE auf
-- eingabefeld.offertentyp_id fehl. Neu: Loeschen verschiebt die Vorlage nur
-- in einen Papierkorb (papierkorb_am gesetzt) - sie verschwindet aus den
-- normalen Listen, bleibt aber wiederherstellbar. Erst im Papierkorb kann sie
-- endgueltig geloescht werden (kaskadierend, applikationsseitig in der
-- richtigen Reihenfolge - siehe einstellungen-live-v1.html).
--
-- papierkorb_am ist bewusst unabhaengig vom bestehenden "ausgeblendet"-Feld:
-- ausgeblendet = vorerst nicht waehlbar fuer neue Offerten, bleibt aber
-- normal in der Verwaltung sichtbar. papierkorb_am = zur Loeschung vorgesehen.
-- ============================================================================

alter table offertentyp add column papierkorb_am timestamptz null;
