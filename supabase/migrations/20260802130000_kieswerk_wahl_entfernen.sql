-- ============================================================================
-- Offertentool 2027 - Manuelle Kieswerk-Wahl entfernt.
--
-- Bisher konnte pro Teilflaeche manuell ein Kieswerk (fuer Kies-/Beton-
-- Transport) angeklickt werden. Das wird nicht mehr gebraucht: das System
-- ermittelt jetzt automatisch das geografisch naechstgelegene Kieswerk zur
-- Kunde-PLZ (aus der jeweiligen Liste in Einstellungen > Rechenlogik >
-- Kies-/Beton-Transport). Welches Kies-/Betonmaterial verbaut wird, ist davon
-- unabhaengig - das laeuft weiterhin als normaler Artikel in einer eigenen
-- Ressourcenzeile.
-- ============================================================================

alter table teilflaeche_auswahl drop column if exists kieswerk_kies_id;
alter table teilflaeche_auswahl drop column if exists kieswerk_beton_id;
