-- Pflege-Arbeit beim Kunden: Jahresrhythmus statt einzelner abgewählter Jahre (2026-11-27).
-- rhythmus_jahre 1 = jedes Jahr, 2 = alle 2 Jahre …; start_jahr = erstes Jahr (null = jedes Jahr ab sofort).
-- fixe_woche (bisher ungenutzt) = «Fix»: Vorschlag direkt in der Personenzeile statt auf der offenen Linie.
alter table public.pflege_kunde_arbeit add column if not exists rhythmus_jahre smallint not null default 1;
alter table public.pflege_kunde_arbeit add column if not exists start_jahr smallint;
alter table public.pflege_kunde_arbeit drop constraint if exists pflege_kunde_arbeit_rhythmus_chk;
alter table public.pflege_kunde_arbeit add constraint pflege_kunde_arbeit_rhythmus_chk check (rhythmus_jahre between 1 and 10);
-- bisher war nur 2026 abgewählt (vorbei) → alle jährlich
update public.pflege_kunde_arbeit set abgewaehlte_jahre = '{}' where coalesce(array_length(abgewaehlte_jahre, 1), 0) > 0;
select count(*) n, count(*) filter (where rhythmus_jahre = 1) jaehrlich from public.pflege_kunde_arbeit;
