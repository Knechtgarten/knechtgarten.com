-- Einmalig (Stefan, 2026-11-12): Gartenpflege-Team (Cornelia Hirschi, Selina Durrer, Samir Akhdar, Andrea Hadorn),
-- Termine 2026/2027 mit «selber abgemacht» (projektleiter_id leer) → zuständig Benu. Kurs/Magazin bleiben.
-- Sicherung der betroffenen IDs in planer_einsatz_sich_20261112 (zum Zurückstellen: projektleiter_id wieder auf null).
create table if not exists public.planer_einsatz_sich_20261112 as
  select id, projektleiter_id from public.planer_einsatz where false;
alter table public.planer_einsatz_sich_20261112 enable row level security;
with z as (
  select id from public.planer_einsatz
   where person_id in ('3bf63074-0b77-4b3c-9150-c8c769b95458','6e1b34eb-fc9b-469c-8290-b717d2c474b3','b2bd722d-9251-4d58-9b6f-38c7b5a2b264','f0fd6735-198f-4acb-9b38-3722c3cf4dc0')
     and projektleiter_id is null and art = 'termin'
     and extract(year from beginn) in (2026, 2027)
     and coalesce(titel, '') !~* '^(kurs|magazin)'
), s as (
  insert into public.planer_einsatz_sich_20261112 (id, projektleiter_id) select id, null from z returning id
)
update public.planer_einsatz e set projektleiter_id = '77831873-ebe1-41fb-a044-20f081652878', geaendert_am = now()
  from s where e.id = s.id;
