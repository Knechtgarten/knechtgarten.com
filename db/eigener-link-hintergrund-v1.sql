-- ============================================================================
-- Offertentool 2027 - Hintergrundfarbe fuer eigene Links: nur der Admin kann
-- sie fuer seine eigenen Links selbst waehlen (Verwaltung), alle anderen
-- Rollen bekommen weiterhin automatisch Grau (kein Auswahlfeld dafuer in
-- index.html) - daher bleibt die Spalte nullable, null = Standard-Grau.
-- ============================================================================

alter table benutzer_eigener_link add column hintergrund text
  check (hintergrund in ('blau', 'gruen', 'grau', 'navy'));
