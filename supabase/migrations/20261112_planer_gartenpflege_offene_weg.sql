-- Einmalig (Stefan, 2026-11-12): Neustart Gartenpflege – alle offenen (nicht abgemachten) Einträge der Gartenpflege-Zeilen löschen,
-- die nicht über das Pflege-Tool angelegt wurden (Tom's-Planner-Übernahme oder lose erfasst). Vollständige Sicherung in planer_einsatz_sich_gp_20261112.
create table if not exists public.planer_einsatz_sich_gp_20261112 as select * from public.planer_einsatz where false;
alter table public.planer_einsatz_sich_gp_20261112 enable row level security;
with z as (
  select e.* from public.planer_einsatz e
    join public.planer_person p on p.id = e.person_id
    join public.planer_gruppe g on g.id = p.gruppe_id
   where g.name ilike '%gartenpflege%' and e.abgemacht = false
     and (e.import_tom_id is not null or e.pflege_kunde_kategorie_id is null)
), s as (insert into public.planer_einsatz_sich_gp_20261112 select * from z returning id)
delete from public.planer_einsatz e using s where e.id = s.id;
