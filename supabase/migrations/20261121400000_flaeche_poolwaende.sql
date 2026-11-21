-- Pool/Wassergarten: Formel «Fläche Poolwände» korrigiert (Stefan 2026-11-21)
-- Bisher Länge × Breite × Tiefe (= Beckenvolumen, falsch). Neu: Umfang Becken innen × Tiefe (= Wandfläche in m²).
-- Wirkt auf Wände betonieren (Schalungssteine, Beton, Armierung, Personal), Wände verputzen, Folie verlegen
-- und «Fläche Gesamtmenge Pool innen» (Wände + Boden).
-- Alte Formel zum Zurücksetzen:
--   {"op":"*","args":[{"op":"*","args":[{"id":"8bd9110e-f946-4cc4-b992-7c0f6e6a9b25","ref":"eingabefeld"},{"id":"2567fa39-6fce-4d16-aa31-f033aa84dad1","ref":"eingabefeld"}]},{"id":"aa352ddd-e412-4de2-97ce-16117858784f","ref":"eingabefeld"}]}
update term set ausdruck = '{"op": "*", "args": [{"id": "cb48054f-2668-400b-8bea-29789b3ecef7", "ref": "term"}, {"id": "aa352ddd-e412-4de2-97ce-16117858784f", "ref": "eingabefeld"}]}'::jsonb
where id = 'bff364d7-0ec3-423a-9443-499909937aa4';

select name, eval_ausdruck(ausdruck, '{"8bd9110e-f946-4cc4-b992-7c0f6e6a9b25": 3, "2567fa39-6fce-4d16-aa31-f033aa84dad1": 1.1, "aa352ddd-e412-4de2-97ce-16117858784f": 0.9}'::jsonb) beispiel_3x1_1x0_9
from term where id = 'bff364d7-0ec3-423a-9443-499909937aa4';
