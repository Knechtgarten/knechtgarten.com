-- ============================================================================
-- Einsatzplaner: Termine übereinander statt reingeschoben
-- uebereinander = true: dieser Termin unterbricht den längeren Termin nicht, beide werden
-- halb hoch übereinander gezeigt (roter Rand). Höchstens zwei Termine pro Halbtag (prüft der Planer).
-- ============================================================================
alter table planer_einsatz add column if not exists uebereinander boolean not null default false;
