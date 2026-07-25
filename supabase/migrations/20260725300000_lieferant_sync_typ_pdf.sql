-- ============================================================================
-- Offertentool 2027 - 'pdf' als eigener Datenabgleich-Typ (Lieferant schickt
-- gelegentlich eine PDF-Preisliste statt eines automatischen Zugangs). PDF
-- steht ausserdem im Abgleich-Fenster IMMER zusaetzlich als Fallback zur
-- Verfuegung, unabhaengig vom hier gespeicherten primaeren sync_typ - das ist
-- reine Anwendungslogik, keine weitere DB-Aenderung noetig.
-- ============================================================================

alter table lieferant drop constraint if exists lieferant_sync_typ_check;
alter table lieferant add constraint lieferant_sync_typ_check
  check (sync_typ in ('manuell','api','crawling','ftp_xml','google_sheet','pdf'));
