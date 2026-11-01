-- ============================================================================
-- Einsatzplaner: drei Ablage-Zeilen unter jeder Gruppe (zum Parkieren beim Planen)
-- Ablage-Personen (ist_ablage) erscheinen nur im Planer, wenn die Ablage eingeschaltet ist –
-- nicht in Personenlisten, Mithilfe-Auswahl, Startseite oder Handy.
-- Gruppen ohne Ablage: Allgemein, Planungshilfe (wird zur Werkzeug-Fussleiste).
-- ============================================================================
alter table planer_person add column if not exists ist_ablage boolean not null default false;

insert into planer_person (gruppe_id, name, kuerzel, ist_vorarbeiter, ist_projektleiter, sortierung, aktiv, ist_ablage)
select g.id, 'Ablage ' || n, null, false, false, 9000 + n, true, true
from planer_gruppe g cross join generate_series(1, 3) n
where g.name not ilike 'allgemein%' and g.name not ilike 'planungshilfe%'
  and not exists (select 1 from planer_person x where x.gruppe_id = g.id and x.ist_ablage and x.name = 'Ablage ' || n);
