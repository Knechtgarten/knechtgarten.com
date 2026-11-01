-- ============================================================================
-- Einsatzplaner: «Wer sich bewegt, gibt nach»
-- weicht = true: dieser Termin wurde zuletzt verschoben/gezogen und überlappt einen bestehenden Termin teilweise.
-- Dort wird er ausgespart (der bestehende bleibt stärker), fehlende Tage zeigt er rot «x von y T».
-- ============================================================================
alter table planer_einsatz add column if not exists weicht boolean not null default false;
