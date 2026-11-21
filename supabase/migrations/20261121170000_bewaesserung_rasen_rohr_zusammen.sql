-- Bewässerung Rasen: Druckrohr PE 25 mm (100-m-Rolle) als eine Zeile: 10 m pro Düse + Zuleitung, erst die Summe auf halbe Rollen aufrunden.
-- Rollen = aufrunden((Düsen × 10 m + Zuleitung 25 mm) ÷ 100 m × 2) ÷ 2
update ressourcenzeile set
  menge_ausdruck = x.a, menge_formel_baukasten_ausdruck = x.a
from (select '{"op": "/", "args": [{"op": "ceil", "args": [{"op": "*", "args": [
    {"op": "+", "args": [
      {"op": "/", "args": [{"id": "81b6b589-db29-4488-acbb-614723b67fef", "ref": "spalte"}, {"lit": 10}]},
      {"op": "/", "args": [{"id": "26ce6c4f-d2ca-44f6-b8ec-dabc0759b673", "ref": "spalte"}, {"lit": 100}]}]},
    {"lit": 2}]}]}, {"lit": 2}]}'::jsonb a) x
where id = '28f4298b-08fa-4392-b0fe-22c42c8cc206';
delete from ressourcenzeile where id = '5b20d21c-45c2-449e-8822-40c5a4cbd7b2';
