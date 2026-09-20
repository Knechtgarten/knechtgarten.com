-- ============================================================================
-- Mail-Assistent: Vorlagen mit Nutzungs-Historie liessen sich nicht mehr
-- loeschen (Fremdschluessel von mailassistent_nutzung_log.vorlage_id blockierte
-- das Loeschen ohne "on delete"-Regel). Die Statistik-Zeile soll beim Loeschen
-- einer Vorlage einfach bestehen bleiben (nur ohne Vorlagen-Bezug), nicht die
-- Loeschung verhindern.
-- ============================================================================

alter table mailassistent_nutzung_log drop constraint if exists mailassistent_nutzung_log_vorlage_id_fkey;
alter table mailassistent_nutzung_log add constraint mailassistent_nutzung_log_vorlage_id_fkey
  foreign key (vorlage_id) references mailassistent_vorlage(id) on delete set null;
