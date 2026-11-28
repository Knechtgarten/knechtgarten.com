-- Platz reservieren (2026-11-28): offene Pflege-Arbeiten mit zuständiger Person halten im Einsatzplaner Platz frei (grüner Rahmen)
alter table public.pflege_arbeit add column if not exists platz_reservieren boolean not null default false; -- Standard pro Standardarbeit
alter table public.pflege_kunde_arbeit add column if not exists platz_reservieren boolean; -- pro Kunde, null = Standard der Arbeit
