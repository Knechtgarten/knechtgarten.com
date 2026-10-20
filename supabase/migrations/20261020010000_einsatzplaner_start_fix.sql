-- ============================================================================
-- Einsatzplaner: Schloss «Start fix» pro Auftrag
-- start_fix = true: Balken laesst sich nicht mehr nach links/rechts ziehen
-- (auf eine andere Person am gleichen Tag und Ende aufziehen geht weiterhin).
-- «Arbeitstage fix» nutzt das bestehende Feld soll_tage.
-- ============================================================================
alter table planer_einsatz add column if not exists start_fix boolean not null default false;
