-- ============================================================================
-- Offertentool 2027 - Interne Notiz fuer Eingabefelder und Werte (Terms).
--
-- Arbeitsschritt und Ressourcenzeile haben bereits ein "notiz"-Feld mit
-- Notiz-Icon im Editor (nur fuer Team sichtbar, nicht im Konfigurator).
-- Eingabefeld und Term bekommen jetzt dasselbe Muster - z.B. um die
-- Herleitung einer Formel (wie beim Aushubkeil) direkt beim Wert zu
-- dokumentieren.
-- ============================================================================

alter table term add column if not exists notiz text null;
alter table eingabefeld add column if not exists notiz text null;
