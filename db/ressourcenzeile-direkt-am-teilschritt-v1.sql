-- ============================================================================
-- Offertentool 2027 - Ressourcenzeile direkt am Teilschritt moeglich
-- Korrektur des Datenmodells (2026-07-21): eine Ressourcenzeile gehoert
-- eigentlich primaer zum Teilschritt, nicht zwingend zu einer Option. Ein
-- Teilschritt OHNE Auswahlfeld hat seine Ressourcenzeilen direkt (gelten
-- immer, wenn der Arbeitsschritt in einer Offerte verwendet wird - keine
-- Buttons fuer den Mitarbeiter). Ein Teilschritt MIT Auswahlfeld (hoechstens
-- eines pro Teilschritt) hat seine Ressourcenzeilen weiterhin pro Option
-- (nur die gewaehlte(n) Option(en) gelten). Eine Ressourcenzeile hat also
-- IMMER genau eine der beiden Referenzen, nie beide, nie keine.
-- ============================================================================

-- Ressourcenzeile: teilschritt_id ergaenzen, option_id darf jetzt leer sein
alter table ressourcenzeile add column teilschritt_id uuid null references teilschritt(id) on delete cascade;
alter table ressourcenzeile alter column option_id drop not null;
alter table ressourcenzeile add constraint ressourcenzeile_teilschritt_oder_option_check
  check (
    (teilschritt_id is not null and option_id is null) or
    (teilschritt_id is null and option_id is not null)
  );

-- Auswahlfeld: hoechstens eines pro Teilschritt
alter table auswahlfeld add constraint auswahlfeld_teilschritt_unique unique (teilschritt_id);
