-- ============================================================================
-- Einsatzplaner: Serientermine (Planungshilfe)
-- Eine Serie wird als einzelne Einträge angelegt; serie_id hält sie zusammen
-- (ganze Serie rückgängig machen / löschen).
-- ============================================================================
alter table planer_einsatz add column if not exists serie_id uuid null;
alter table planer_markierung add column if not exists serie_id uuid null;
create index if not exists planer_einsatz_serie_idx on planer_einsatz (serie_id) where serie_id is not null;
create index if not exists planer_markierung_serie_idx on planer_markierung (serie_id) where serie_id is not null;
