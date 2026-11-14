-- Vorlage Mauern: «Blendmauer» heisst neu «Verblendmauer» (Tabelle, Zeilennamen in Offerten, Teilschritt Zusatzarbeiten)
update public.eingabefeld set name = 'Verblendmauer' where name = 'Blendmauer';
update public.offerte_tabelle_zeile z set name = regexp_replace(z.name, '^Blendmauer', 'Verblendmauer')
  from public.eingabefeld e where e.id = z.eingabefeld_id and e.name = 'Verblendmauer' and z.name like 'Blendmauer%';
update public.teilschritt set name = replace(name, 'Blendmauer', 'Verblendmauer') where name like '%Blendmauer%' and name not like '%Verblendmauer%';
select 'eingabefeld' t, name from public.eingabefeld where name ilike '%blendmauer%'
union all select 'teilschritt', name from public.teilschritt where name ilike '%blendmauer%';
-- Terme in Tool B gleich benennen
update public.term set name = replace(name, 'Blendmauer', 'Verblendmauer') where name like '%Blendmauer%' and name not like '%Verblendmauer%';
