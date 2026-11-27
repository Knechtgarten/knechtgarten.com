-- Planer: allgemeine Zeilen «Termine & Infos» → «Team» (gilt für alle, Rahmen durch alle Zeilen, im Handy als Info),
-- «Arbeitszeit & Ferien» → «Büro» (Lieferungen, Schulferien, Büro-Hinweise; nur oben). Lieferungen wandern in die Büro-Zeile.
update public.planer_markierung m set person_id = b.id
  from public.planer_person t, public.planer_person b
  where m.person_id = t.id and t.name = 'Termine & Infos' and b.name = 'Arbeitszeit & Ferien' and m.art = 'liefer';
update public.planer_person set name = 'Team' where name = 'Termine & Infos';
update public.planer_person set name = 'Büro' where name = 'Arbeitszeit & Ferien';
select name, (select count(*) from public.planer_markierung m where m.person_id = p.id) markierungen
  from public.planer_person p where name in ('Team', 'Büro', 'Maschinenservice');
