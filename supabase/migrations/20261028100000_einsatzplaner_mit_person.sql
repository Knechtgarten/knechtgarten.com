-- ============================================================================
-- Einsatzplaner: Mithilfe auch bei einer Person ohne Baustelle/Termin im Zeitraum
-- planer_einsatz.mit_person_id   «Mit …» direkt bei einer Person (wenn kein
--                                Einsatz zum Verknüpfen da ist)
-- ============================================================================
alter table planer_einsatz add column if not exists mit_person_id uuid null references planer_person(id) on delete set null;
