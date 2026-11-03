-- Bauprogramm: Notizen pro Block (eigene Spalte im Programm)
alter table public.bauprogramm_block add column if not exists notiz text;
