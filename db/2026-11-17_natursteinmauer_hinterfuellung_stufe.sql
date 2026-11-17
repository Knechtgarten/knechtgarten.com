-- Natursteinmauer: Hinterfüllung abgestuft nach Mauerhöhe (Stefan, 17.11.2026)
--   Höhe = Sichthöhe ohne Fundament
--   bis 1.00 m hoch  → ganze Mauer 0.30 m hinterfüllt
--   über 1.00 m hoch → ganze Mauer 0.50 m hinterfüllt
--   Hinterfüllvolumen = Breite × Höhe × Länge (ohne Längenzuschlag 2 × 30 cm)
-- Die Formel-Sprache kennt kein «wenn» – die Stufe kommt aus dem Aufrunden:
--   AUFRUNDEN( (AUFRUNDEN(H) − 1) / (AUFRUNDEN(H) + 0.000001) ) = 0 bis 1.00 m, 1 darüber
--   Breite = 0.30 + 0.20 × Stufe
-- Die Spalte «Hinterfüllbreite» wird nicht mehr gebraucht → ausgeblendet (Werte bleiben gespeichert).

update public.eingabefeld_tabelle_spalte set ausdruck = '{"op": "*", "args": [
  {"op": "+", "args": [
    {"lit": 0.3},
    {"op": "*", "args": [
      {"lit": 0.2},
      {"op": "ceil", "args": [
        {"op": "/", "args": [
          {"op": "-", "args": [{"op": "ceil", "args": [{"id": "e517568d-a9a1-4f1e-807c-d96a63a1338e", "ref": "spalte"}]}, {"lit": 1}]},
          {"op": "+", "args": [{"op": "ceil", "args": [{"id": "e517568d-a9a1-4f1e-807c-d96a63a1338e", "ref": "spalte"}]}, {"lit": 0.000001}]}
        ]}
      ]}
    ]}
  ]},
  {"op": "*", "args": [
    {"id": "e517568d-a9a1-4f1e-807c-d96a63a1338e", "ref": "spalte"},
    {"id": "88e34834-df78-43c0-9b8d-41b5b252ef6e", "ref": "spalte"}
  ]}
]}'::jsonb
where id = '3ccb5b97-3823-4012-9b7d-a65f28ccc2c6';

update public.eingabefeld_tabelle_spalte set ausgeblendet = true where id = '6a3b0508-9ca7-4acc-8f49-590abd67f67a';

select name, ausgeblendet, left(ausdruck::text, 80) from public.eingabefeld_tabelle_spalte
where id in ('3ccb5b97-3823-4012-9b7d-a65f28ccc2c6', '6a3b0508-9ca7-4acc-8f49-590abd67f67a');
