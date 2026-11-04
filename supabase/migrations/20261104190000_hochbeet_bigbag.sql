-- Hochbeet / Trog befüllen: dritter Knopf «Substrat, Big Bag».
-- Artikel Ökohum Dach- und Trogerde intensiv, Big Bag 1,5 m³ (Art.-Nr. 619200):
-- EP 256.00/m³ (Preisliste, 1–2 Paletten, wie beim Sack), VP 320.00/m³ = gleiches Verhältnis wie Sack in Easybill (12.90 / 10.30).
do $$
declare
  s_menge uuid := 'fc1d4e35-0678-46bb-8fec-528f6eedfd40';
  s_fl    uuid := '0f9298f3-4cb6-43f7-8e69-825933a8d00d';
  s_vol   uuid := '45cceafe-c08e-4382-ae85-e19345e759c1';
  a_ga    uuid := '794454dd-c8a4-457a-ab66-b69fa4f6ea81';
  a_va    uuid := '006e6793-37de-46e2-8a0b-45a0065313db';
  a_blaeh uuid := '8b08b03c-7c1f-4e06-9581-0d06cf672be4';
  a_vlies uuid := '3868f6af-1fcc-44b7-ae3d-791ab74f2b27';
  a_bag uuid; af uuid; o_bag uuid; verweis jsonb; vol jsonb; fl jsonb; menge jsonb; netto jsonb; std jsonb;
begin
  select f.id into af from auswahlfeld f join teilschritt t on t.id = f.teilschritt_id where t.name = 'Hochbeet / Trog befüllen' and f.name = 'Befüllung';
  if af is null then raise exception 'Teilschritt Hochbeet / Trog befüllen fehlt'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af and name = 'Substrat, Big Bag') then raise notice 'schon vorhanden'; return; end if;

  select id into a_bag from artikel where artikelnummer_knecht = 'OEKOHUM_-619200' limit 1;
  if a_bag is null then
    insert into artikel (lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant_chf, vp_knecht)
      values ('68147038-9d19-4864-9e16-ec3578ee0a80', 'material', 'OEKOHUM_-619200', '619200', 'Ökohum Dach und Trogerde intensiv, Big Bag 1,5 m³', 'm³', 256, 320) returning id into a_bag;
  end if;

  select tabellenverweis into verweis from auswahloption where auswahlfeld_id = af and name = 'Substrat, Säcke à 30 l';
  vol := jsonb_build_object('ref', 'spalte', 'id', s_vol); fl := jsonb_build_object('ref', 'spalte', 'id', s_fl); menge := jsonb_build_object('ref', 'spalte', 'id', s_menge);
  netto := jsonb_build_object('op', '-', 'args', jsonb_build_array(vol, jsonb_build_object('op', '*', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 0.2)))));
  std := jsonb_build_object('op', '+', '_einheit', 'Std.', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(vol, jsonb_build_object('lit', 1.0))), jsonb_build_object('op', '*', 'args', jsonb_build_array(menge, jsonb_build_object('lit', 0.15))), jsonb_build_object('lit', 1)));

  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, mehrfachauswahl, mengenoption, tabellenverweis)
    values (af, 'Substrat, Big Bag', 3, 'Hochbeet mit Trogerde aus dem Big Bag befüllen, inkl. Blähton-Drainageschicht 20 cm und Trenngewebe', true, false, verweis) returning id into o_bag;
  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, reihenfolge, menge_formel_modus, mengenoption_ausgenommen, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4) values
    (o_bag, 'material', a_bag, jsonb_build_object('op', '*', '_einheit', 'm³', 'args', jsonb_build_array(netto, jsonb_build_object('lit', 1))), 1, 'baukasten', true, '1','1','1','1'),
    (o_bag, 'material', a_blaeh, jsonb_build_object('op', 'ceil', '_einheit', 'Sack', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 4))))), 2, 'baukasten', true, '1','1','1','1'),
    (o_bag, 'material', a_vlies, jsonb_build_object('op', '*', '_einheit', 'm²', 'args', jsonb_build_array(fl, jsonb_build_object('lit', 1.2))), 3, 'baukasten', true, '1','1','1','1'),
    (o_bag, 'personal', a_va, std, 4, 'baukasten', true, '1','1','1','1'),
    (o_bag, 'personal', a_ga, std, 5, 'baukasten', true, '1','1','1','1');
end $$;
