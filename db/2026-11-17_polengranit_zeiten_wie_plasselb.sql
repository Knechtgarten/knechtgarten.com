-- Mauern: Polengranit (Grossmengen franko + Kleinmengen, alle Optionen 30er M/L, 40er L, 50er L)
-- bekommt die gleichen Zeiten wie «Mauer geschichtet» (Plasselb Maschine M/L), Stefan 17.11.2026:
--   Polier + Gartenarbeiter 2.5 (vorher 2.2) · Raupenbagger 1.5 (vorher 1.32) · Dumper 0.5 (vorher 1.32)
-- Kleingeräte (0.1 Std.) bleiben – Plasselb hat diese Zeile nicht.
with ziel as (
  select r.id, r.kategorie, ar.bezeichnung art
  from ressourcenzeile r join auswahloption o on o.id = r.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
  join teilschritt t on t.id = af.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
  join offertentyp ot on ot.id = a.offertentyp_id left join artikel ar on ar.id = r.artikel_id
  where ot.name = 'Mauern' and t.name ilike 'Polengranit%' and r.kategorie in ('personal', 'maschine')
)
update ressourcenzeile r set menge_ausdruck = case
    when z.kategorie = 'personal' then '{"lit": 2.5}'::jsonb
    when z.art ilike 'Raupenbagger%' then '{"lit": 1.5}'::jsonb
    when z.art ilike '%Dumper%' then '{"lit": 0.5}'::jsonb
  end
from ziel z
where r.id = z.id and (z.kategorie = 'personal' or z.art ilike 'Raupenbagger%' or z.art ilike '%Dumper%');

select t.name, o.name opt, ar.bezeichnung, r.menge_ausdruck::text
from ressourcenzeile r join auswahloption o on o.id = r.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
join teilschritt t on t.id = af.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
join offertentyp ot on ot.id = a.offertentyp_id left join artikel ar on ar.id = r.artikel_id
where ot.name = 'Mauern' and t.name ilike 'Polengranit%' and r.kategorie in ('personal', 'maschine')
order by t.name, o.name, r.reihenfolge;
