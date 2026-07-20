-- ============================================================================
-- Offertentool 2027 - Betrag pro Offerte speichern
-- Fuer die Offerten-Liste in Tool A (Sidebar), damit dort der Betrag jeder
-- Offerte angezeigt werden kann, ohne bei jedem Seitenaufbau alle Offerten
-- neu durchzurechnen. Wird bei jedem Speichern in Tool A aktualisiert.
-- ============================================================================
alter table offerte add column betrag_total numeric not null default 0;
