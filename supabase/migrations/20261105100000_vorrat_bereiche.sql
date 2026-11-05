-- Planer-Vorrat: zusätzliche Bereiche «Lehrlinge» und «Andere» (je eigene Zeile), Herkunft beim Import aus Tom's Planner
alter table planer_vorrat drop constraint if exists planer_vorrat_bereich_check;
alter table planer_vorrat add constraint planer_vorrat_bereich_check check (bereich in ('bau', 'pflege', 'lehrling', 'andere'));
alter table planer_vorrat add column if not exists import_tom_id text;
create unique index if not exists planer_vorrat_import_tom_id_uq on planer_vorrat (import_tom_id) where import_tom_id is not null;
