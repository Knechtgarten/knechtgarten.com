-- Einsatzplaner: Einsatz als erledigt markieren (ersetzt bei Pflege-Terminen das Abhaken im Jahresplan;
-- dort wird zusaetzlich pflege_einsatz_status geschrieben, damit das Pflege-Tool es weiterhin sieht).
alter table planer_einsatz add column if not exists erledigt boolean not null default false;
alter table planer_einsatz add column if not exists erledigt_am timestamptz null;
