-- Bepflanzung › Gefässe: mehr Arbeitszeit ab ca. 50 cm (Stefan 2026-11-21)
-- Jeweils die nächsthöhere Zeit (Polier und Gartenarbeiter), kleine Gefässe (0.2 Std., U40/HK40/Austin 45) bleiben:
--   0.3 → 0.4, 0.4 → 0.5, 0.5 → 0.6, 0.6 → 0.8, 0.8 → 1.0, 1.0 → 1.5 (grösste: U100, Naimo 110)
-- Gilt für Atelier Vierkant U-Form, Atelier Vierkant HK-Form und Jaco Gefässe.
update ressourcenzeile r
set menge_ausdruck = jsonb_set(r.menge_ausdruck, '{lit}', to_jsonb(case (r.menge_ausdruck->>'lit')::numeric
      when 0.3 then 0.4 when 0.4 then 0.5 when 0.5 then 0.6 when 0.6 then 0.8 when 0.8 then 1.0 when 1.0 then 1.5 end))
from auswahloption o, auswahlfeld f, teilschritt t, arbeitsschritt a, offertentyp ot
where o.id = r.option_id and f.id = o.auswahlfeld_id and t.id = f.teilschritt_id and a.id = t.arbeitsschritt_id and ot.id = a.offertentyp_id
  and ot.name = 'Bepflanzung' and t.name in ('Atelier Vierkant U-Form', 'Atelier Vierkant HK-Form', 'Jaco Gefässe')
  and r.kategorie = 'personal' and r.menge_ausdruck ? 'lit' and r.menge_ausdruck - 'lit' - '_einheit' = '{}'::jsonb
  and (r.menge_ausdruck->>'lit')::numeric in (0.3, 0.4, 0.5, 0.6, 0.8, 1.0);

select t.name ts, string_agg(o.name || '=' || coalesce((select string_agg(distinct r.menge_ausdruck->>'lit', '/') from ressourcenzeile r where r.option_id = o.id and r.kategorie = 'personal'), '-'), ', ' order by o.reihenfolge) x
from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id join offertentyp ot on ot.id = a.offertentyp_id
where ot.name = 'Bepflanzung' and t.name in ('Atelier Vierkant U-Form', 'Atelier Vierkant HK-Form', 'Jaco Gefässe') group by t.name, t.reihenfolge order by t.reihenfolge;
