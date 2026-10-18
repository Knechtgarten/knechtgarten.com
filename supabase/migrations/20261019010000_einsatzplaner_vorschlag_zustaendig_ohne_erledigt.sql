-- Pflege-Vorschlag: neben der Notiz auch «Zuständig» merken (geht beim Abmachen in den Einsatz).
alter table planer_vorschlag_notiz alter column notiz drop not null;
alter table planer_vorschlag_notiz add column if not exists projektleiter_id uuid null references planer_person(id) on delete set null;
-- Erledigt-Knopf entfällt (Stefan 2026-10-19): Pflege-Termine gelten nach ihrem Tag automatisch als erledigt.
-- Die Spalten waren noch leer (nie benutzt).
alter table planer_einsatz drop column if exists erledigt;
alter table planer_einsatz drop column if exists erledigt_am;
