-- ============================================================================
-- Offertentool 2027 - Verknuepfung lokaler Kunden mit Easybill
--
-- Wird beim Anlegen eines Kunden aus einem Easybill-Suchtreffer gesetzt (siehe
-- Edge Function easybill-kunden-suche + Kunde-Suchfeld in Tool A/A2). Rein
-- informativ/fuer spaetere Abgleiche - kein automatischer Ruecksync noetig,
-- siehe Architektur-Entscheid (nur lesender Zugriff auf Easybill).
-- ============================================================================

alter table kunde add column easybill_id bigint null unique;
