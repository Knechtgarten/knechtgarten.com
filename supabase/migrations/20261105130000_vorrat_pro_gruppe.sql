-- Einsatzplaner: Arbeitsvorrat pro Gruppe (unter dem Gruppentitel). Neuer Bereich «pool» (nur technische Pool-Arbeiten).
alter table public.planer_vorrat drop constraint if exists planer_vorrat_bereich_check;
alter table public.planer_vorrat add constraint planer_vorrat_bereich_check check (bereich in ('bau', 'pflege', 'pool', 'lehrling', 'andere'));
-- welcher Vorrat-Bereich unter welchem Gruppentitel steht
alter table public.planer_gruppe add column if not exists vorrat_bereich text check (vorrat_bereich in ('bau', 'pflege', 'pool'));
update public.planer_gruppe set vorrat_bereich = 'pool' where name ilike 'pool%';
update public.planer_gruppe set vorrat_bereich = 'bau' where name ilike '%gartenbau%';
update public.planer_gruppe set vorrat_bereich = 'pflege' where name ilike '%gartenpflege%';
