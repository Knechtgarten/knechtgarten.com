-- Planer: Herkunft beim Import aus Tom's Planner (Balken-Id), damit der Import eindeutig und rückgängig machbar ist
alter table planer_einsatz add column if not exists import_tom_id text;
create unique index if not exists planer_einsatz_import_tom_id_uq on planer_einsatz (import_tom_id) where import_tom_id is not null;
