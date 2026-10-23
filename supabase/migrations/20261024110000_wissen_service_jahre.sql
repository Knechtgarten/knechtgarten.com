-- ============================================================================
-- Wissen & Geräte: Service-Arbeit nur in bestimmten Jahren (z. B. alle 2 Jahre).
-- Gespeichert werden die abgewählten Jahre (wie beim Pflegeabo), leer = jedes Jahr.
-- ============================================================================
alter table wissen_service add column if not exists aus_jahre int[] not null default '{}';
