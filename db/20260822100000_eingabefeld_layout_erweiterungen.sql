-- ============================================================================
-- Eingabefeld: drei neue optionale Layout-/Eingabehilfen fuer den Konfigurator
-- in Tool A, konfigurierbar im Eingabefeld-Editor in Tool B.
-- - zeilennummer: erzwingt eine eigene Zeile im Konfigurator (0 = vor den
--   Feldern ohne Zeilennummer, 1/2/3... = danach, jeweils in eigener Zeile).
-- - zusatztext: kurzer Text, der im Konfigurator unter dem Feldnamen (ueber
--   dem Eingabefeld) angezeigt wird, z.B. "Vor dem Haus".
-- - flaechenformel_moeglich: blendet im Konfigurator ein Rechner-Icon ein,
--   mit dem der Wert wahlweise als Formel (z.B. "5x9+2x3") statt direkt
--   eingegeben werden kann.
-- ============================================================================

alter table eingabefeld add column zeilennummer integer;
alter table eingabefeld add column zusatztext text;
alter table eingabefeld add column flaechenformel_moeglich boolean not null default false;
