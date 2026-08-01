-- ============================================================================
-- Offertentool 2027 - Pruefstatus des "Prüfen"-Buttons dauerhaft speichern.
--
-- Bisher war das Ergebnis (Gefunden/Fehler) nur im Browser sichtbar und
-- verschwand beim Neuladen der Seite - man musste jede Adresse nach jedem
-- Reload erneut pruefen, um zu sehen, was schon verifiziert wurde. Jetzt
-- wird das Ergebnis direkt an der Adresse gespeichert und bleibt auf einen
-- Blick sichtbar. Wird beim Aendern der Adresse automatisch wieder
-- zurueckgesetzt (siehe Tool B), da die alte Pruefung dann nicht mehr gilt.
-- ============================================================================

alter table kieswerk_distanz add column if not exists geprueft_ok boolean null;
alter table kieswerk_distanz add column if not exists geprueft_fehler text null;

alter table deponie_distanz add column if not exists geprueft_ok boolean null;
alter table deponie_distanz add column if not exists geprueft_fehler text null;

alter table lieferwagen_konfiguration add column if not exists herkunft_geprueft_ok boolean null;
alter table lieferwagen_konfiguration add column if not exists herkunft_geprueft_fehler text null;
