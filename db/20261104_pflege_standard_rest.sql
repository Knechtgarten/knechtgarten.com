-- Pflege-Tool: Standardzeit für die übrigen Arbeiten = Median der Kunden, die schon eine Zeit haben.
-- Ohne Daten (Annahme): Kübelpflanzen 2 Std., Dusche 1 Std., Zierbecken entleeren & reinigen 4 Std. (Sheet Feierabend KW 38).
update pflege_arbeit a set dauer_min = m.median
from (select ka.arbeit_id, percentile_disc(0.5) within group (order by ka.dauer_min) median
      from pflege_kunde_arbeit ka where ka.dauer_min is not null group by ka.arbeit_id) m
where m.arbeit_id = a.id and a.dauer_min is null;
update pflege_arbeit a set dauer_min = v.min from (values ('GP', 'Kübelpflanzen', 120), ('PO', 'Dusche', 60), ('ZB', 'Entleerung & Reinigung', 240)) as v(kat, name, min), pflege_kategorie c
where c.id = a.kategorie_id and c.kuerzel = v.kat and a.name = v.name and a.dauer_min is null;
