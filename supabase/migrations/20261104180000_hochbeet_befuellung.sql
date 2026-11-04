-- Bepflanzung › Gefässe befüllt: neuer Teilschritt «Hochbeet / Trog befüllen».
-- Zwei Optionen (Big Bag folgt, sobald es einen Artikel Trogerde Big Bag gibt) mit Tabellenverweis auf die Tabelle «Trog, Hochbeet» (Spalte Volumen):
-- unter jedem Knopf hakt man an, welche Hochbeete damit befüllt werden.
-- In den Mengenformeln stehen Fläche/Volumen/Menge dann nur für die angehakten Zeilen.
-- Blähton-Schicht 20 cm, Trenngewebe Fläche × 1,2, kein Setzungszuschlag.
-- Ausserdem: Volumen = Menge × Fläche × Höhe (vorher ohne Menge), Menge-Vorschlag 1.
do $$
declare
  t_tab   uuid := '4fd86c5b-eeeb-4d27-a5ed-dee94d3828ef';  -- Tabelle «Trog, Hochbeet»
  s_menge uuid := 'fc1d4e35-0678-46bb-8fec-528f6eedfd40';
  s_fl    uuid := '0f9298f3-4cb6-43f7-8e69-825933a8d00d';
  s_hoehe uuid := '1caafe6e-7047-481f-8c9c-4478731a4ebf';
  s_vol   uuid := '45cceafe-c08e-4382-ae85-e19345e759c1';
  a_ga    uuid := '794454dd-c8a4-457a-ab66-b69fa4f6ea81';  -- Gartenarbeiter
  a_va    uuid := '006e6793-37de-46e2-8a0b-45a0065313db';  -- Polier / Vorarbeiter
  a_trog  uuid := 'f904ab9a-dc8a-4e64-abd9-7f2ebdf66724';  -- Ökohum Dach und Trogerde intensiv 30L
  a_blaeh uuid := '8b08b03c-7c1f-4e06-9581-0d06cf672be4';  -- Ökohum Blähton 50l
  a_vlies uuid := '3868f6af-1fcc-44b7-ae3d-791ab74f2b27';  -- Sytec Geofiltergewebe HF 1300
  a_bag   uuid := '46f6264e-a80b-4fbf-bbff-4972f0cbe86a';  -- Big Bag
  a_humus uuid;
  ts uuid; af uuid; o_land uuid; o_sack uuid;
  verweis jsonb;
  vol jsonb; fl jsonb; menge jsonb; netto jsonb;
begin
  if exists (select 1 from teilschritt where arbeitsschritt_id = 'd9604cdf-1fa0-4201-a057-128a4dd37b6e' and name = 'Hochbeet / Trog befüllen') then
    raise notice 'schon vorhanden'; return;
  end if;

  -- Artikel Humus ab Lager (aus Easybill 10-000120: VP 84.00, EP 67.00 pro m³)
  select id into a_humus from artikel where artikelnummer_knecht = '10-000120' limit 1;
  if a_humus is null then
    insert into artikel (lieferant_id, kategorie, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant_chf, vp_knecht, easybill_id)
      values ('db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'material', '10-000120', 'Kulturerde Knecht (Humus) lose, gesiebt', 'm³', 67, 84, '4311786') returning id into a_humus;
  end if;

  -- Volumen mit Menge
  update eingabefeld_tabelle_spalte set ausdruck = jsonb_build_object('op', '*', 'args', jsonb_build_array(
      jsonb_build_object('ref', 'spalte', 'id', s_menge),
      jsonb_build_object('ref', 'spalte', 'id', s_fl),
      jsonb_build_object('op', '*', '_umrechnung', true, 'args', jsonb_build_array(jsonb_build_object('ref', 'spalte', 'id', s_hoehe), jsonb_build_object('lit', 0.01)))))
  where id = s_vol;
  update eingabefeld_tabelle_spalte set vorschlagswert = 1 where id = s_menge and vorschlagswert is null;

  verweis := jsonb_build_array(jsonb_build_object('eingabefeld_id', t_tab, 'spalte_id', s_vol, 'gruppe', 'befuellung', 'wort', 'Hochbeet'));
  vol   := jsonb_build_object('ref', 'spalte', 'id', s_vol);
  fl    := jsonb_build_object('ref', 'spalte', 'id', s_fl);
  menge := jsonb_build_object('ref', 'spalte', 'id', s_menge);
  netto := jsonb_build_object('op', '-', 'args', jsonb_build_array(vol, jsonb_build_object('op', '*', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 0.2)))));  -- Volumen ohne Blähton

  insert into teilschritt (arbeitsschritt_id, name, beschreibung, reihenfolge)
    values ('d9604cdf-1fa0-4201-a057-128a4dd37b6e', 'Hochbeet / Trog befüllen', 'Hochbeete und Tröge aus der Tabelle «Trog, Hochbeet» befüllen', 4) returning id into ts;
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (ts, 'Befüllung', 1) returning id into af;

  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, mehrfachauswahl, mengenoption, tabellenverweis)
    values (af, 'Landerde (Humus ab Lager)', 1, 'Hochbeet mit Humus ab Lager Knecht befüllen, lose', true, false, verweis) returning id into o_land;
  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, mehrfachauswahl, mengenoption, tabellenverweis)
    values (af, 'Substrat, Säcke à 30 l', 2, 'Hochbeet mit Trogerde befüllen, inkl. Blähton-Drainageschicht 20 cm und Trenngewebe', true, false, verweis) returning id into o_sack;

  -- Landerde: pro m³ (Menge der Option = Volumen der angehakten Hochbeete)
  insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, reihenfolge, menge_formel_modus, mengenoption_ausgenommen, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4) values
    (o_land, 'material', a_humus, null, jsonb_build_object('lit', 1, '_einheit', 'm³'), 1, 'baukasten', false, '1','1','1','1'),
    (o_land, 'personal', a_va, null, jsonb_build_object('op', '+', '_einheit', 'Std.', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(vol, jsonb_build_object('lit', 1.0))), jsonb_build_object('lit', 1))), 2, 'baukasten', true, '1','1','1','1'),
    (o_land, 'personal', a_ga, null, jsonb_build_object('op', '+', '_einheit', 'Std.', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(vol, jsonb_build_object('lit', 1.0))), jsonb_build_object('lit', 1))), 3, 'baukasten', true, '1','1','1','1');

  -- Substrat in Säcken (wie Excel: Sack 30 l, 0,04 Std. pro Sack, 0,15 Std. Trenngewebe pro Gefäss, 1 Std. bereitstellen)
  insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, reihenfolge, menge_formel_modus, mengenoption_ausgenommen, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4) values
    (o_sack, 'material', a_trog, null, jsonb_build_object('op', 'ceil', '_einheit', 'Sack', 'args', jsonb_build_array(jsonb_build_object('op', '/', 'args', jsonb_build_array(netto, jsonb_build_object('lit', 0.03))))), 1, 'baukasten', true, '1','1','1','1'),
    (o_sack, 'material', a_blaeh, null, jsonb_build_object('op', 'ceil', '_einheit', 'Sack', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 4))))), 2, 'baukasten', true, '1','1','1','1'),
    (o_sack, 'material', a_vlies, null, jsonb_build_object('op', '*', '_einheit', 'm²', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 1.2))), 3, 'baukasten', true, '1','1','1','1'),
    (o_sack, 'personal', a_va, null, jsonb_build_object('op', '+', '_einheit', 'Std.', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(vol, jsonb_build_object('lit', 1.33))), jsonb_build_object('op', '*', 'args', jsonb_build_array(menge, jsonb_build_object('lit', 0.15))), jsonb_build_object('lit', 1))), 4, 'baukasten', true, '1','1','1','1'),
    (o_sack, 'personal', a_ga, null, jsonb_build_object('op', '+', '_einheit', 'Std.', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(vol, jsonb_build_object('lit', 1.33))), jsonb_build_object('op', '*', 'args', jsonb_build_array(menge, jsonb_build_object('lit', 0.15))), jsonb_build_object('lit', 1))), 5, 'baukasten', true, '1','1','1','1');

end $$;
