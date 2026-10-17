-- ============================================================================
-- Pflege-Tool: Loesch-Schutz fuer Zustaendigkeiten
--
-- Bisher hat das Loeschen einer Person (benutzer) ihre Zustaendigkeiten im
-- Pflege-Tool stillschweigend mitgeloescht (ON DELETE CASCADE). Neu verhindert
-- die Datenbank das: Solange jemand noch zustaendig ist, schlaegt das Loeschen
-- fehl - auch direkt im Supabase-Dashboard. Die Verwaltung fragt deshalb vor dem
-- Loeschen, an wen die Zustaendigkeiten gehen (pflege_zustaendig_uebertragen).
-- Das Umschreiben der id (Platzhalter -> echter Login) zieht weiterhin mit.
-- ============================================================================
alter table pflege_kunde_kategorie_zustaendig drop constraint pflege_kunde_kategorie_zustaendig_benutzer_id_fkey;
alter table pflege_kunde_kategorie_zustaendig add constraint pflege_kunde_kategorie_zustaendig_benutzer_id_fkey
  foreign key (benutzer_id) references benutzer(id) on delete restrict on update cascade;
