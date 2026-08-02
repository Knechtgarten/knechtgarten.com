-- ============================================================================
-- Offertentool 2027 - Standard-Auswahl pro Auswahloption.
--
-- Bisher wurde bei einer neuen Offerte immer automatisch die ERSTE Option
-- (nach Reihenfolge) jedes Auswahlfelds vorausgewaehlt - unabhaengig davon,
-- ob das inhaltlich sinnvoll war. Neu kann in Tool B pro Option ein Haekchen
-- "Standardmaessig ausgewaehlt" gesetzt werden. Ist bei keiner Option eines
-- Auswahlfelds das Haekchen gesetzt, ist bei einer neuen Offerte fuer dieses
-- Auswahlfeld standardmaessig KEINE Option ausgewaehlt (statt wie bisher
-- immer die erste).
-- ============================================================================

alter table auswahloption add column if not exists ist_standard boolean not null default false;
