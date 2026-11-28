-- Turnus einer Arbeit beim Kunden: zusätzlich ein letztes Jahr (null = unbefristet). 2026-11-28
alter table public.pflege_kunde_arbeit add column if not exists ende_jahr smallint;
select count(*) from public.pflege_kunde_arbeit where ende_jahr is not null;
