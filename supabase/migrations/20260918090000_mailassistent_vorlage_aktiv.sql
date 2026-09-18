-- ============================================================================
-- Mail-Assistent: Vorlagen koennen ausgeblendet werden, ohne sie zu loeschen.
--
-- Neues Feld "aktiv" (Standard: true). Bei false bleibt die Vorlage in der
-- Verwaltung sichtbar/bearbeitbar, taucht aber weder als Chip in Gmail
-- (Verfassen) noch als Option fuer die KI (Antworten) mehr auf.
-- ============================================================================

alter table mailassistent_vorlage
  add column if not exists aktiv boolean not null default true;
