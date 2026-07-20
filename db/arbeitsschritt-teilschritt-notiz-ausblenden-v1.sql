-- ============================================================================
-- Offertentool 2027 - Notiz + Ausblenden fuer Arbeitsschritt/Teilschritt (Tool B)
-- Notiz: interne Admin-Notiz pro Arbeitsschritt (z.B. "bei Kran-Kombination
-- Ruecksprache wegen Zusatzkosten"), erscheint nirgends in Tool A.
-- Ausblenden: reversibel - ausgeblendete Arbeitsschritte/Teilschritte bleiben
-- mitsamt allen Daten erhalten, erscheinen aber nicht mehr als waehlbare
-- Option in Tool A (nur in Tool B weiterhin sichtbar, abgeblendet).
-- ============================================================================
alter table arbeitsschritt add column notiz text;
alter table arbeitsschritt add column ausgeblendet boolean not null default false;
alter table teilschritt add column ausgeblendet boolean not null default false;
