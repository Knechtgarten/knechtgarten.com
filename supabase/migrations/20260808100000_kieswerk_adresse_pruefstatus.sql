-- ============================================================================
-- Offertentool 2027 - Adress-Pruefstatus fuer Kies-/Beton-Transport-Kieswerke.
--
-- Gleiches Muster wie bei den Distanz-Adresslisten in Tool B (kieswerk_distanz/
-- deponie_distanz) und beim Lieferwagen-Standort: ein "Pruefen"-Button prueft
-- die Adresse ueber die distance-matrix Edge Function und speichert das
-- Ergebnis, damit man auf einen Blick sieht, welche Kieswerk-Adressen
-- tatsaechlich gefunden werden - in der Vergangenheit hat eine nicht
-- auffindbare Adresse zu falschen Berechnungen gefuehrt.
-- ============================================================================

alter table kieswerk_kies add column if not exists geprueft_ok boolean null;
alter table kieswerk_kies add column if not exists geprueft_fehler text null;
alter table kieswerk_beton add column if not exists geprueft_ok boolean null;
alter table kieswerk_beton add column if not exists geprueft_fehler text null;
