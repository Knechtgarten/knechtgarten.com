-- Bewässerung: Druckrohr PE (16 mm 50-m-Rolle, 25 mm 100-m-Rolle) auf halbe Rollen aufrunden (Stefan 2026-11-21).
-- Menge = aufrunden(bisherige Rollen × 2) ÷ 2, z. B. 10 m / 50 m = 0.2 → 0.5 Rollen; 30 m → 1.0; 60 m → 1.5.
create or replace function pg_temp.halbe_rolle(x jsonb) returns jsonb language sql immutable as $$
  select case when x is null then null else jsonb_build_object('op', '/', 'args', jsonb_build_array(
    jsonb_build_object('op', 'ceil', 'args', jsonb_build_array(
      jsonb_build_object('op', '*', 'args', jsonb_build_array(x, '{"lit": 2}'::jsonb)))),
    '{"lit": 2}'::jsonb)) end
$$;
update ressourcenzeile r set
  menge_ausdruck = pg_temp.halbe_rolle(r.menge_ausdruck),
  menge_formel_baukasten_ausdruck = pg_temp.halbe_rolle(r.menge_formel_baukasten_ausdruck)
from artikel a, teilschritt t, arbeitsschritt ar
where a.id = r.artikel_id and t.id = r.teilschritt_id and ar.id = t.arbeitsschritt_id
  and ar.offertentyp_id = '96e3eee2-27f4-4161-af6f-1614afac07c9' and a.bezeichnung ilike 'Druckrohr PE LD%'
  and r.menge_ausdruck->>'op' = '/' and r.menge_ausdruck::text not like '%ceil%';
