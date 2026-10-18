-- ============================================================================
-- Einsatzplaner: Farben wie in Tom's Planner (Stand 2026-10-18)
-- Projektleiter (Benu, Stefu, Fäbu, Päscu) = Farbe der Baustellenbalken.
-- Mitarbeitende, die (zwischendurch) eine Baustelle leiten = eigene Farbe
-- (Punkt beim Namen, «Mit …»-Balken der Hilfskräfte). Lehrlinge/Hilfskräfte,
-- die nie leiten = keine Farbe. Vorarbeiter = Equipe Gartenbau + Räphu.
-- ============================================================================

-- Projektleiter als eigene Zeilen in der Gruppe «Büro», verknüpft mit ihrem Login
insert into planer_person (name, kuerzel, gruppe_id, farbe, ist_projektleiter, benutzer_id, sortierung)
select v.name, v.kuerzel, g.id, v.farbe, true, v.bid::uuid, v.sort
from (values
  ('Benu', 'Benu', '#7A7A38', '033a207f-7834-433c-9369-3a09ebff58f5', 10),
  ('Stefan', 'Stefu', '#7E9282', '59840bbb-c123-4d85-9b75-0c171a35ec9f', 20),
  ('Fabian Oberholzer', 'Fäbu', '#62B54E', '6b59611a-6065-4578-b12a-204923545e39', 30),
  ('Pascal Wüthrich', 'Päscu', '#9DBBAA', '93790c9c-35ea-4943-afc8-a6f245d5c2af', 40)
) v(name, kuerzel, farbe, bid, sort)
cross join planer_gruppe g
where g.name = 'Büro' and not exists (select 1 from planer_person p where p.benutzer_id = v.bid::uuid);

update planer_person p set farbe = v.farbe, kuerzel = coalesce(p.kuerzel, v.kuerzel), ist_vorarbeiter = v.va
from (values
  ('Dominic Glur', '#4646B8', 'Dominic', true),
  ('Marco Gfeller', '#B3CDF5', 'Marco', false),
  ('Fabian Reusser', '#93BCBC', 'Fäbu', true),
  ('Kai Abgottspon', '#7DB8D6', 'Kai', true),
  ('Raphael Walther', '#6E5A8C', 'Räphu', true),
  ('Stefanie Röthlisberger', '#A97BB5', 'Stefanie', true),
  ('Remo Reusser', '#E8A8D0', 'Remo', true),
  ('Timo Jost', '#A84E8A', 'Timo', true),
  ('Cornelia Hirschi', '#F2E64E', 'Cornelia', false),
  ('Selina Durrer', '#F6F2B0', 'Selina', false),
  ('Samir Akhdar', '#E3CC4E', 'Samir', false),
  ('Andrea Hadorn', '#E8A84A', 'Andrea', false),
  ('Sandra Rufener', '#E58A3A', 'Sandra', false)
) v(name, farbe, kuerzel, va)
where p.name = v.name;

-- Lehrlinge / Hilfskräfte ohne eigene Baustellen: keine Farbe
update planer_person set farbe = null
where name in ('Dian Baumann', 'Tamino Zaugg', 'Gonzalo Rodea', 'Tim Bürki', 'Nick Gersbach');
