-- ============================================================================
-- Rolle "verkauf" umbenennen in "mitarbeiter"
-- Muss auf der bereits laufenden Datenbank nachgezogen werden (rls-und-
-- rollen-v1.sql ist schon gelaufen und wird nicht erneut ausgefuehrt).
-- ============================================================================

alter table benutzer drop constraint benutzer_rolle_check;
update benutzer set rolle = 'mitarbeiter' where rolle = 'verkauf';
alter table benutzer add constraint benutzer_rolle_check check (rolle in ('admin','mitarbeiter'));
