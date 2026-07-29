-- ============================================================================
-- Offertentool 2027 - sync_typ wird zum "Favorisierter Datenabgleich": legt
-- pro Lieferant fest, welche Methode im Lieferanten-Abgleich-Tool direkt
-- gezeigt wird (statt der bisherigen Quelle-Auswahl, die dort gar nicht
-- gespeichert wurde und bei jedem Besuch wieder auf Crawling zurueckfiel).
-- Neu: 'schnellerfassung' als moegliche Wahl - fuer Lieferanten, die man
-- bewusst nur ueber den Schnellimport pflegt (der bleibt bei allen
-- Lieferanten trotzdem immer zusaetzlich nutzbar).
-- ============================================================================

alter table lieferant drop constraint if exists lieferant_sync_typ_check;
alter table lieferant add constraint lieferant_sync_typ_check
  check (sync_typ in ('manuell','api','crawling','ftp_xml','google_sheet','pdf','schnellerfassung'));
