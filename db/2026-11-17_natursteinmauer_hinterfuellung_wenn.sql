-- Natursteinmauer: Hinterfüllvolumen mit dem neuen WENN statt der Aufrunden-Krücke (gleiches Ergebnis)
--   WENN(Höhe > 1; 0.5; 0.3) × Höhe × Länge
update public.eingabefeld_tabelle_spalte set
  formel_modus = 'text',
  formel_text = 'WENN({Höhe::spalte:e517568d-a9a1-4f1e-807c-d96a63a1338e} > 1; 0.5; 0.3) * {Höhe::spalte:e517568d-a9a1-4f1e-807c-d96a63a1338e} * {Länge::spalte:88e34834-df78-43c0-9b8d-41b5b252ef6e}',
  ausdruck = '{"op": "*", "args": [
    {"op": "*", "args": [
      {"op": "wenn", "args": [
        {"op": ">", "args": [{"id": "e517568d-a9a1-4f1e-807c-d96a63a1338e", "ref": "spalte"}, {"lit": 1}]},
        {"lit": 0.5},
        {"lit": 0.3}
      ]},
      {"id": "e517568d-a9a1-4f1e-807c-d96a63a1338e", "ref": "spalte"}
    ]},
    {"id": "88e34834-df78-43c0-9b8d-41b5b252ef6e", "ref": "spalte"}
  ]}'::jsonb
where id = '3ccb5b97-3823-4012-9b7d-a65f28ccc2c6';

-- Kontrolle: 0.7 × 8.5 → 1.785 · 1.0 × 10 → 3.0 · 1.01 × 10 → 5.05 · 1.2 × 26 → 15.6
select h, l, public.eval_ausdruck((select ausdruck from public.eingabefeld_tabelle_spalte where id = '3ccb5b97-3823-4012-9b7d-a65f28ccc2c6'),
  jsonb_build_object('e517568d-a9a1-4f1e-807c-d96a63a1338e', h, '88e34834-df78-43c0-9b8d-41b5b252ef6e', l)) vol
from (values (0.7, 8.5), (1.0, 10.0), (1.01, 10.0), (1.2, 26.0), (0.0, 0.0)) v(h, l);
