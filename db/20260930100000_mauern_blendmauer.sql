-- ============================================================================
-- Mauern: neuer Arbeitsschritt "Blendmauer" mit Option "Betonwand".
--
-- Eingabe: Tabelle "Blendmauer" - pro Zeile eine Mauer mit Länge, Höhe und Dicke
--          (mehrere Mauern möglich). Berechnet werden Fläche (m²) und Volumen (m³).
-- Formeln: "Fläche Blendmauer" und "Volumen Blendmauer" (Summe über alle Zeilen).
-- Zeilen der Option "Betonwand": Arbeitszeit, Betonpumpe, Beton-Transport,
--          SVB Beton, Armierung, Entsorgung, Schmiermischung, Geräte -
--          Artikel/Sonderpositionen aus dem Pool übernommen (Wände betonieren /
--          Bodenplatte), Mengen auf Fläche bzw. Volumen der Blendmauer umgehängt.
-- Die Mengen sind ein erster Entwurf (Pool-Werte) und in Tool B anpassbar.
-- ============================================================================
do $$
declare
  ot uuid; pool_ot uuid;
  ef_alt uuid; ef_tab uuid := gen_random_uuid();
  sp_l uuid := gen_random_uuid(); sp_h uuid := gen_random_uuid(); sp_d uuid := gen_random_uuid();
  sp_fl uuid := gen_random_uuid(); sp_vol uuid := gen_random_uuid();
  t_fl uuid := gen_random_uuid(); t_vol uuid := gen_random_uuid();
  as_alt uuid; ts_alt uuid; af_alt uuid; opt_alt uuid;
  as_neu uuid := gen_random_uuid(); ts_neu uuid := gen_random_uuid(); af_neu uuid := gen_random_uuid(); opt_neu uuid := gen_random_uuid();
  j jsonb; rec record; rr int := 0;
  fl jsonb; vol jsonb;
  ref_fl jsonb; ref_vol jsonb;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into pool_ot from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  if ot is null or pool_ot is null then raise exception 'Vorlage Mauern oder Pool nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Blendmauer') then
    raise exception 'Arbeitsschritt Blendmauer gibt es schon - nichts geaendert.';
  end if;

  select e.id into ef_alt from eingabefeld e where e.offertentyp_id = ot and e.ist_tabelle limit 1;
  select a.id into as_alt from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Fundation';
  select ts.id into ts_alt from teilschritt ts where ts.arbeitsschritt_id = as_alt limit 1;
  select af.id into af_alt from auswahlfeld af where af.teilschritt_id = ts_alt limit 1;
  select o.id into opt_alt from auswahloption o where o.auswahlfeld_id = af_alt order by o.reihenfolge limit 1;
  if ef_alt is null or as_alt is null or ts_alt is null or af_alt is null or opt_alt is null then
    raise exception 'Musterzeilen der Vorlage Mauern nicht gefunden';
  end if;

  -- 1) Tabelle "Blendmauer"
  select to_jsonb(e) into j from eingabefeld e where e.id = ef_alt;
  j := j || jsonb_build_object('id', ef_tab, 'name', 'Blendmauer',
        'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from eingabefeld where offertentyp_id = ot));
  insert into eingabefeld select * from jsonb_populate_record(null::eingabefeld, j);

  fl  := jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('id', sp_l, 'ref','spalte'), jsonb_build_object('id', sp_h, 'ref','spalte')));
  vol := jsonb_build_object('op','*','args', jsonb_build_array(
           jsonb_build_object('id', sp_fl, 'ref','spalte'),
           jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('id', sp_d, 'ref','spalte'), jsonb_build_object('lit', 0.01)), '_umrechnung', true)));

  for rec in
    select * from (values
      (sp_l,  'Länge',  'm',  1, false, null::jsonb, null::numeric),
      (sp_h,  'Höhe',   'm',  2, false, null::jsonb, null::numeric),
      (sp_d,  'Dicke',  'cm', 3, false, null::jsonb, 20::numeric),
      (sp_fl, 'Fläche', 'm²', 4, true,  fl,  null::numeric),
      (sp_vol,'Volumen','m³', 5, true,  vol, null::numeric)
    ) as v(id, name, einheit, reihenfolge, berechnet, ausdruck, vorschlag)
  loop
    select to_jsonb(s) into j from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef_alt order by (case when s.ist_berechnung then 1 else 0 end), s.reihenfolge limit 1;
    j := j || jsonb_build_object('id', rec.id, 'eingabefeld_id', ef_tab, 'name', rec.name, 'einheit', rec.einheit,
          'reihenfolge', rec.reihenfolge, 'ist_berechnung', rec.berechnet, 'ausdruck', rec.ausdruck,
          'vorschlagswert', rec.vorschlag, 'zusatztext_moeglich', false, 'flaechenformel_moeglich', false,
          'formel_modus', 'baukasten', 'formel_text', null, 'formel_baukasten_ausdruck', null,
          'ist_dropdown', false, 'dropdown_leer_label', null, 'dropdown_pflicht', false);
    insert into eingabefeld_tabelle_spalte select * from jsonb_populate_record(null::eingabefeld_tabelle_spalte, j);
  end loop;

  -- 2) Formeln (Summe der Spalten ueber alle Zeilen)
  select to_jsonb(t) into j from term t where t.offertentyp_id = ot and t.typ = 'formel' limit 1;
  j := j || jsonb_build_object('id', t_fl, 'name', 'Fläche Blendmauer', 'einheit', 'm²',
        'ausdruck', jsonb_build_object('id', sp_fl, 'ref', 'spalte'),
        'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot),
        'formel_modus', 'baukasten', 'formel_text', null, 'formel_baukasten_ausdruck', null);
  insert into term select * from jsonb_populate_record(null::term, j);
  j := j || jsonb_build_object('id', t_vol, 'name', 'Volumen Blendmauer', 'einheit', 'm³',
        'ausdruck', jsonb_build_object('id', sp_vol, 'ref', 'spalte'),
        'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from term where offertentyp_id = ot));
  insert into term select * from jsonb_populate_record(null::term, j);
  ref_fl  := jsonb_build_object('id', t_fl,  'ref', 'term');
  ref_vol := jsonb_build_object('id', t_vol, 'ref', 'term');

  -- 3) Arbeitsschritt > Teilschritt > Auswahlfeld > Option
  select to_jsonb(a) into j from arbeitsschritt a where a.id = as_alt;
  j := j || jsonb_build_object('id', as_neu, 'name', 'Blendmauer', 'reihenfolge', (select coalesce(max(reihenfolge), 0) + 1 from arbeitsschritt where offertentyp_id = ot));
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, j);
  select to_jsonb(ts) into j from teilschritt ts where ts.id = ts_alt;
  j := j || jsonb_build_object('id', ts_neu, 'arbeitsschritt_id', as_neu, 'name', 'Blendmauer', 'reihenfolge', 1, 'beschreibung', null);
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j);
  select to_jsonb(af) into j from auswahlfeld af where af.id = af_alt;
  j := j || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', 'Blendmauer');
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j);
  select to_jsonb(o) into j from auswahloption o where o.id = opt_alt;
  j := j || jsonb_build_object('id', opt_neu, 'auswahlfeld_id', af_neu, 'name', 'Betonwand', 'reihenfolge', 1,
        'beschreibung', 'Blendmauer aus Beton erstellen.', 'mengenoption', false, 'mehrfachauswahl', false,
        'tabellenverweis', null, 'hinweistext', null, 'hinweisbild_url', null);
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);

  -- 4) Ressourcenzeilen der Option "Betonwand" (aus dem Pool kopiert, Mengen angepasst)
  --    (Quelle Option, Quelle Reihenfolge, neue Menge-Formel oder null = unveraendert uebernehmen)
  for rec in
    select * from (values
      ('Wände betonieren',   1,  jsonb_build_object('op','*','args', jsonb_build_array(ref_fl, jsonb_build_object('lit', 1.1)))),
      ('Wände betonieren',   2,  jsonb_build_object('op','*','args', jsonb_build_array(ref_fl, jsonb_build_object('lit', 1.1)))),
      ('Bodenplatte armiert',3,  ref_vol),
      ('Bodenplatte armiert',4,  ref_vol),
      ('Bodenplatte armiert',5,  ref_vol),
      ('Wände betonieren',   10, jsonb_build_object('op','*','args', jsonb_build_array(ref_fl, jsonb_build_object('lit', 8)))),
      ('Wände betonieren',   8,  null::jsonb),
      ('Wände betonieren',   9,  null::jsonb),
      ('Wände betonieren',   12, jsonb_build_object('lit', 2))
    ) as v(quelle, rz_r, formel)
  loop
    select to_jsonb(rz) into j
      from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld af on af.id = o.auswahlfeld_id
      join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
     where a.offertentyp_id = pool_ot and o.name = rec.quelle and rz.reihenfolge = rec.rz_r
     order by rz.id limit 1;
    if j is null then raise exception 'Pool-Zeile % / % nicht gefunden - nichts geaendert.', rec.quelle, rec.rz_r; end if;
    rr := rr + 1;
    j := j || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_neu, 'teilschritt_id', null, 'reihenfolge', rr,
          'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null);
    if rec.formel is not null then j := j || jsonb_build_object('menge_ausdruck', rec.formel); end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
  end loop;

  raise notice 'Blendmauer angelegt: Tabelle %, Arbeitsschritt %, % Zeilen.', ef_tab, as_neu, rr;
end $$;
