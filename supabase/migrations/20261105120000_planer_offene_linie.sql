-- Einsatzplaner: Gruppen mit «offener Linie» (nicht abgemachte Aufträge in einer eigenen Zeile unter jeder Person)
alter table public.planer_gruppe add column if not exists offene_linie boolean not null default false;
update public.planer_gruppe set offene_linie = true where name ilike 'pool%' or name ilike '%gartenbau%' or name ilike '%gartenpflege%';
