-- ============================================================================
-- Mail-Assistent: Anzahl-Spalte bei Tabellen-Zusatzfenstern abschaltbar.
-- Nicht jede Tabelle braucht eine Stueckzahl (z.B. reine Materialangaben wie
-- Flaeche/Holzart/Laenge ohne "wie viele Stueck") - bisher war die
-- Anzahl-Spalte immer fix dabei.
-- ============================================================================

alter table mailassistent_zusatzfenster add column if not exists zeigt_anzahl boolean not null default true;
