-- Bepflanzung > Mulchen > Lavamulch: Menge war aus Ökohum-Sack kopiert (Fläche x 0.05 / 0.045 = Säcke), Artikel ist aber in m³.
-- Richtig: Pflanzfläche Total x 0.05 m (5 cm Schicht) = m³.
update ressourcenzeile set menge_ausdruck = jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('id', '31d73422-1be9-489a-8679-58ebff85549d', 'ref', 'term'), jsonb_build_object('lit', 0.05)))
where option_id = '16802fb3-a0f8-45dc-bdaf-3c92628afacc' and artikel_id = (select id from artikel where bezeichnung = 'Lavamulch 2-8mm');
