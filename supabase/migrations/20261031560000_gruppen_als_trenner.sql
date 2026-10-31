-- Gruppen = Trenner in der Liste: Gruppentitel und Pendenzen teilen sich eine Reihenfolge (sortierung).
-- Alles unter einem Gruppentitel (bis zum nächsten) gehört zu dieser Gruppe.
-- Bestehende Reihenfolge so umnummerieren, dass das bisherige Bild bleibt:
-- zuerst die Pendenzen ohne Gruppe (1, 2, 3 …), dann jede Gruppe (10000, 20000 …) mit ihren Pendenzen direkt danach.
with g as (
  select id, liste_id, row_number() over (partition by liste_id order by sortierung, titel) * 10000 as basis
  from pendenz_gruppe
)
update pendenz_gruppe pg set sortierung = g.basis from g where g.id = pg.id;

alter table pendenz_gruppe alter column sortierung type double precision;

with o as (
  select p.id,
         coalesce(g.sortierung, 0) + row_number() over (partition by p.liste_id, p.gruppe_id order by p.sortierung, p.erstellt_am) as neu
  from pendenz p
  left join pendenz_gruppe g on g.id = p.gruppe_id
  where p.liste_id in (select liste_id from pendenz_gruppe)
)
update pendenz p set sortierung = o.neu from o where o.id = p.id;
