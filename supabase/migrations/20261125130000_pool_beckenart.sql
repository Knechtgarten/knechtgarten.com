-- Pool/Wassergarten: «Konstruktion» (cm) wird Auswahlfeld «Beckenart»
--   1 Fertigbecken: 15 cm Wand (wird gefüllt) + 10 cm Arbeitsraum
--   2 Betonbecken:  20 cm Wand (nicht gefüllt) + 10 cm Arbeitsraum
--   3 Badebrunnen:  keine Wand, 10 cm Arbeitsraum
-- Aushub und Hinterfüllung mit Keil 2:1 (Böschungsfaktor 0.5); Füllhöhe endet unter dem Betonkragen.
alter table eingabefeld add column if not exists auswahl_werte jsonb;
alter table eingabefeld drop constraint if exists eingabefeld_typ_check;
alter table eingabefeld add constraint eingabefeld_typ_check check (typ = any (array['zahl', 'ja_nein', 'auswahl']));

do $$
declare
  ot uuid := '83bf9ae8-3095-4194-a9bb-4ea2dc08473e';
  ef_art uuid := '62115639-35a2-496c-bb95-7180086d9b28';  -- bisher «Konstruktion»
  ef_b uuid := '2567fa39-6fce-4d16-aa31-f033aa84dad1';    -- Breite innen (m)
  ef_l uuid := '8bd9110e-f946-4cc4-b992-7c0f6e6a9b25';    -- Länge innen (m)
  ef_t uuid := 'aa352ddd-e412-4de2-97ce-16117858784f';    -- Tiefe (m)
  ef_ue uuid := '15da288c-e87d-472f-958a-37a0b957d296';   -- Über Terrain (cm)
  ef_kr uuid := 'b696aac3-d727-4476-8b8f-6013d4c5d0d4';   -- Betonkragen (cm)
  t_breite uuid := 'a515933b-ce97-4c33-8a41-dabb68448181';
  t_laenge uuid := '297e5992-8e28-498e-a8ec-8c75e700bbff';
  t_umfang uuid := 'ffe57f9f-8ba8-4b7a-b0e5-e4de7c22f6c3';
  t_boesch uuid := '4252f08d-8986-4e5e-b869-822f5039f941';
  t_streifen uuid := 'eb670975-d41c-4b8f-adb3-0bf0159fa7d8';
  t_fuell uuid := 'f4170c78-5b08-47a6-a4db-b909adfa2dfa';
  k_wf uuid; k_wb uuid; k_ar uuid; t_wand uuid; t_zug uuid; t_fb uuid; t_fh uuid; t_keil uuid;
  rf int;
begin
  if exists (select 1 from term where offertentyp_id = ot and name = 'Wandstärke Fertigbecken') then return; end if;
  select coalesce(max(reihenfolge), 0) into rf from term where offertentyp_id = ot;

  -- Konstanten (cm)
  insert into term (offertentyp_id, name, einheit, typ, wert, formel_modus, reihenfolge, erklaerung)
    values (ot, 'Wandstärke Fertigbecken', 'cm', 'konstante', 15, 'baukasten', rf + 1, 'PP-Becken: Wand inkl. Rippen. Wird mit der Hinterfüllung gefüllt.') returning id into k_wf;
  insert into term (offertentyp_id, name, einheit, typ, wert, formel_modus, reihenfolge, erklaerung)
    values (ot, 'Wandstärke Betonbecken', 'cm', 'konstante', 20, 'baukasten', rf + 2, 'Coffra / Ortbeton. Wird nicht gefüllt.') returning id into k_wb;
  insert into term (offertentyp_id, name, einheit, typ, wert, formel_modus, reihenfolge, erklaerung)
    values (ot, 'Arbeitsraum unten', 'cm', 'konstante', 10, 'baukasten', rf + 3, 'Abstand ausserhalb der Wand auf der Bodenplatte, ab hier beginnt der Keil.') returning id into k_ar;

  -- Wandstärke (m) = Fertigbecken 15 / Betonbecken 20 / Badebrunnen 0
  insert into term (offertentyp_id, name, einheit, typ, formel_modus, reihenfolge, ausdruck) values (ot, 'Wandstärke Becken', 'm', 'formel', 'baukasten', rf + 4,
    jsonb_build_object('op', '*', 'args', jsonb_build_array(
      jsonb_build_object('op', '+', 'args', jsonb_build_array(
        jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('op', '=', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_art), jsonb_build_object('lit', 1))), jsonb_build_object('ref', 'term', 'id', k_wf))),
        jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('op', '=', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_art), jsonb_build_object('lit', 2))), jsonb_build_object('ref', 'term', 'id', k_wb))))),
      jsonb_build_object('lit', 0.01)))) returning id into t_wand;
  -- Zugabe pro Seite (m) = Wand + Arbeitsraum
  insert into term (offertentyp_id, name, einheit, typ, formel_modus, reihenfolge, ausdruck) values (ot, 'Zugabe Bodenplatte pro Seite', 'm', 'formel', 'baukasten', rf + 5,
    jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', t_wand),
      jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', k_ar), jsonb_build_object('lit', 0.01)))))) returning id into t_zug;
  -- Füllbreite (m) = Fertigbecken: Wand + Arbeitsraum, sonst nur Arbeitsraum
  insert into term (offertentyp_id, name, einheit, typ, formel_modus, reihenfolge, ausdruck) values (ot, 'Füllbreite neben Becken', 'm', 'formel', 'baukasten', rf + 6,
    jsonb_build_object('op', '*', 'args', jsonb_build_array(
      jsonb_build_object('op', '+', 'args', jsonb_build_array(
        jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('op', '=', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_art), jsonb_build_object('lit', 1))), jsonb_build_object('ref', 'term', 'id', k_wf))),
        jsonb_build_object('ref', 'term', 'id', k_ar))),
      jsonb_build_object('lit', 0.01)))) returning id into t_fb;
  -- Füllhöhe (m) = Tiefe − Über Terrain − Betonkragen
  insert into term (offertentyp_id, name, einheit, typ, formel_modus, reihenfolge, ausdruck) values (ot, 'Füllhöhe Hinterfüllung', 'm', 'formel', 'baukasten', rf + 7,
    jsonb_build_object('op', '-', 'args', jsonb_build_array(
      jsonb_build_object('op', '-', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_t),
        jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_ue), jsonb_build_object('lit', 0.01)), '_umrechnung', true))),
      jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_kr), jsonb_build_object('lit', 0.01)), '_umrechnung', true)))) returning id into t_fh;
  -- Keil Hinterfüllung (m³) = ½ × Füllhöhe² × Böschungsfaktor × Umfang Bodenplatte
  insert into term (offertentyp_id, name, einheit, typ, formel_modus, reihenfolge, ausdruck) values (ot, 'Volumen Keil Hinterfüllung', 'm³', 'formel', 'baukasten', rf + 8,
    jsonb_build_object('op', '*', 'args', jsonb_build_array(
      jsonb_build_object('op', '*', 'args', jsonb_build_array(
        jsonb_build_object('op', '*', 'args', jsonb_build_array(
          jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', 0.5), jsonb_build_object('ref', 'term', 'id', t_fh))),
          jsonb_build_object('ref', 'term', 'id', t_fh))),
        jsonb_build_object('ref', 'term', 'id', t_boesch))),
      jsonb_build_object('ref', 'term', 'id', t_umfang)))) returning id into t_keil;

  -- Bodenplatte = innen + 2 × Zugabe
  update term set ausdruck = jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_b),
    jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', 2), jsonb_build_object('ref', 'term', 'id', t_zug))))) where id = t_breite;
  update term set ausdruck = jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_l),
    jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', 2), jsonb_build_object('ref', 'term', 'id', t_zug))))) where id = t_laenge;
  -- Keil 2:1
  update term set wert = 0.5, erklaerung = 'Neigung der Baugrube: 0.5 = 2:1 (2 m tief, 1 m nach hinten). Gilt für Aushub und Hinterfüllung.' where id = t_boesch;
  -- Streifen neben dem Becken = (Bodenplatte − ungefüllte Fläche) × Füllhöhe; ungefüllt = innen + Betonwand
  update term set name = 'Volumen Füllung neben Becken', ausdruck = jsonb_build_object('op', '*', 'args', jsonb_build_array(
    jsonb_build_object('op', '-', 'args', jsonb_build_array(
      jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', t_laenge), jsonb_build_object('ref', 'term', 'id', t_breite))),
      jsonb_build_object('op', '*', 'args', jsonb_build_array(
        jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_l),
          jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', 2), jsonb_build_object('op', '-', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', t_zug), jsonb_build_object('ref', 'term', 'id', t_fb))))))),
        jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'eingabefeld', 'id', ef_b),
          jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', 2), jsonb_build_object('op', '-', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', t_zug), jsonb_build_object('ref', 'term', 'id', t_fb))))))))))),
    jsonb_build_object('ref', 'term', 'id', t_fh))) where id = t_streifen;
  -- Hinterfüllung total = Streifen + Keil (Keil jetzt mit Füllhöhe statt Aushubtiefe)
  update term set ausdruck = jsonb_build_object('op', '+', 'args', jsonb_build_array(jsonb_build_object('ref', 'term', 'id', t_streifen), jsonb_build_object('ref', 'term', 'id', t_keil))) where id = t_fuell;

  -- Eingabefeld «Konstruktion» → Auswahl «Beckenart»
  update eingabefeld set name = 'Beckenart', typ = 'auswahl', einheit = '', fixer_wert = 1, mindestwert = null,
    auswahl_werte = '[{"text":"Fertigbecken","wert":1},{"text":"Betonbecken","wert":2},{"text":"Badebrunnen","wert":3}]'::jsonb,
    erklaerung = E'Fertigbecken (PP): 15 cm Wand + 10 cm Arbeitsraum, beides wird hinterfüllt.\nBetonbecken (Coffra, Ortbeton): 20 cm Wand + 10 cm, nur ausserhalb der Wand hinterfüllt.\nBadebrunnen: keine Konstruktion, 10 cm + Keil.\nKeil 2:1, oberhalb nur bis unter den Betonkragen. Masse: Konstanten in Tool B.'
  where id = ef_art;

  -- Bestehende Offerten: Betonbecken (Wände betonieren / Folie verlegen), Badebrunnen (Titel), sonst Fertigbecken
  update offerte_eingabefeld_wert w set wert = case
      when exists (select 1 from offerte_auswahl oa join auswahloption o on o.id = oa.option_id join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
                   where oa.offerte_id = w.offerte_id and ts.name = 'Beckenkörper Beton' and o.name in ('Wände betonieren', 'Folie verlegen')) then 2
      when (select titel from offerte where id = w.offerte_id) ilike '%badebrunnen%' then 3
      else 1 end
  where w.eingabefeld_id = ef_art;
end $$;
