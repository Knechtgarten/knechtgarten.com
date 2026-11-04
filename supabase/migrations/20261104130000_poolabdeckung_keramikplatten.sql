-- Poolabdeckung «Abdeckung Unterflur inkl. Sitzbank»: Keramikplatten als Sitzbankabdeckung.
-- Platten 60 × 120 cm, quer verlegt (60 cm entlang der Sitzbank), eine Reihe.
-- Anzahl Platten = aufrunden((Breite innen + 0.10 m Verschnitt) / 0.60 m) – jede angefangene Platte zählt ganz;
-- Menge in m², weil der Artikel pro m² verrechnet wird: Anzahl × 0.72 m².
update ressourcenzeile set reihenfolge = reihenfolge + 1
where option_id = '213a1e82-1218-402e-a3ad-e167b029a0f7' and reihenfolge >= 7;

insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, menge_formel_modus)
values ('213a1e82-1218-402e-a3ad-e167b029a0f7', 'material', '0eaccf30-c6be-406e-9697-6d15691bed5d',
  '{"op": "*", "args": [
     {"op": "ceil", "args": [{"op": "/", "args": [{"op": "+", "args": [{"id": "2567fa39-6fce-4d16-aa31-f033aa84dad1", "ref": "eingabefeld"}, {"lit": 0.1}]}, {"lit": 0.6}]}]},
     {"lit": 0.72}]}'::jsonb,
  'Keramikplatten 60×120 cm quer verlegt, eine Reihe: Platten = aufrunden((Breite innen + 10 cm) / 60 cm), × 0.72 m²',
  1, 1, 1, 1, 7, 'baukasten');
