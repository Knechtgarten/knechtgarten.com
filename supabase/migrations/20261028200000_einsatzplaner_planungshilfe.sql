-- ============================================================================
-- Einsatzplaner: Gruppe «Planungshilfe» (über dem Archiv) mit 8 Ablagezeilen
-- Zum Zwischenparkieren von Einsätzen beim Umplanen. Keine Farbe, kein Vorarbeiter.
-- ============================================================================
insert into planer_gruppe (name, sortierung)
select 'Planungshilfe', 90 where not exists (select 1 from planer_gruppe where name = 'Planungshilfe');
insert into planer_person (name, gruppe_id, sortierung, aktiv)
select 'Ablage ' || i, (select id from planer_gruppe where name = 'Planungshilfe'), i * 10, true
from generate_series(1, 8) i
where not exists (select 1 from planer_person p join planer_gruppe g on g.id = p.gruppe_id where g.name = 'Planungshilfe');
