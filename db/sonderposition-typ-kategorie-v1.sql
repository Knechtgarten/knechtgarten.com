-- ============================================================================
-- Offertentool 2027 - Kategorie fest an sonderposition_typ hinterlegen statt
-- bei jeder Verwendung in Tool B manuell abzufragen.
--
-- sonderposition_typ hat (anders als Staffelgruppe/Zonengruppe) keinen
-- verknuepften Artikel, aus dem sich die Kategorie ableiten liesse - bisher
-- musste sie deshalb bei jedem Hinzufuegen manuell gewaehlt werden. Da jede
-- sonderposition_typ-Zeile ohnehin eigens programmierte Logik braucht (siehe
-- sonderpositionen-v1.sql), ist es naheliegend, die Kategorie gleich einmalig
-- am Katalog-Eintrag selbst zu hinterlegen. Nullable, damit aeltere, vor
-- dieser Umstellung angelegte Eintraege (falls vorhanden) nicht brechen -
-- Tool B faellt fuer diese weiterhin auf die manuelle Auswahl zurueck.
-- ============================================================================

alter table sonderposition_typ add column kategorie text null
  check (kategorie in ('personal','maschine','logistik','material'));

update sonderposition_typ set kategorie = 'logistik' where name in ('Kies-Transport', 'Beton-Transport');
