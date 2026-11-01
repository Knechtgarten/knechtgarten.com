-- ============================================================================
-- Einsatzplaner: lange Termine (mehr als 1 Tag) haben immer fixe Arbeitstage (soll_tage),
-- der Planer setzt sie automatisch. tage_frei = true: im Seitenfenster ausgeschaltet, keine fixen Tage.
-- ============================================================================
alter table planer_einsatz add column if not exists tage_frei boolean not null default false;
