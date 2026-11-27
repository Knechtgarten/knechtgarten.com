-- Büro-Zeile oben, Team darunter. Team-Zeile = nur noch Team-Anlässe (alle weg von der Baustelle) + Info-Icons:
-- doppelte Obstbaumschnittkurse (stehen bei den Lehrlingen) und alter Weekendweg raus.
update public.planer_person set sortierung = 5 where name = 'Büro' and gruppe_id = (select id from public.planer_gruppe where name = 'Allgemein');
delete from public.planer_einsatz e using public.planer_person t
  where e.person_id = t.id and t.name = 'Team' and (e.titel like 'Obstbaumschnittkurs%' or e.titel like 'Weekendweg%');
select e.titel, e.beginn::date from public.planer_einsatz e join public.planer_person t on t.id = e.person_id where t.name = 'Team';
