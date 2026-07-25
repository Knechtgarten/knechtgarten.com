-- ============================================================================
-- Offertentool 2027 - Separater, frei aenderbarer "Titel" fuer Sonderpositionen
-- (Kartenname in Einstellungen), getrennt vom "Name" (gesperrt, wird intern
-- fuer den Sonderposition-Picker in Tool B und - bei Kies-/Beton-Transport -
-- fuer die Berechnung in Tool A verwendet).
--
-- Der Name bleibt bewusst gesperrt (siehe vorherige Migration), damit die
-- Berechnung nicht kaputtgeht. Der Titel ist rein kosmetisch und jederzeit
-- aenderbar - faellt auf den Namen zurueck, solange kein eigener Titel
-- gesetzt ist.
-- ============================================================================

alter table staffelgruppe add column titel text null;
alter table zonengruppe add column titel text null;
alter table sonderposition_typ add column titel text null;
