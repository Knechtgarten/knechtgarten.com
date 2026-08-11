-- ============================================================================
-- Offertentool 2027 - Bugfix: 'direkt' (Lieferwagentransport Einzelfahrt)
-- fehlte in der CHECK-Regel von sonderposition_typ.lieferwagen_transport_ort.
-- Dadurch schlug jedes Speichern einer neuen Position unter "Lieferwagen-
-- transport Einzelfahrt" mit einem Datenbankfehler fehl.
-- ============================================================================

alter table sonderposition_typ drop constraint if exists sonderposition_typ_lieferwagen_transport_ort_check;
alter table sonderposition_typ add constraint sonderposition_typ_lieferwagen_transport_ort_check
  check (lieferwagen_transport_ort in ('kieswerk_betonwerk', 'deponie', 'magazin', 'direkt'));
