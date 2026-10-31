-- Pooloptionen > Gegenstromanlage: Umbau auf drei Auswahlfelder (Anlage / Einbaunische / Blende), damit der Preis ohne Minuszeile stimmt
--  Anlage:   EVA 175 Control Eco, EVA 225 Control 1/2, EVA 275 Control 1/2 (Turbine + Controller + Schlauch + Hilfsmaterial + 9+9 Std., ohne Nische/Blende)
--  Nische:   Polypropylen (116016) oder Edelstahl (116005), je voller Preis
--  Blende:   ABS anthrazit (116018) oder Edelstahl (116020), je voller Preis
--  "InverJet ???" (leer) gelöscht. EVA 275 verwendete fälschlich Next 350 (116053), jetzt Next 275 (116052).
do $$
declare
  ot uuid; as_id uuid; ts_a uuid; af_a uuid; ts_n uuid := gen_random_uuid(); af_n uuid := gen_random_uuid(); ts_b uuid := gen_random_uuid(); af_b uuid := gen_random_uuid();
  o175 uuid; o225 uuid; o275 uuid; o225b uuid := gen_random_uuid(); o275b uuid := gen_random_uuid();
  nisch_es uuid; blende_abs uuid; blende_es uuid; nisch_neu uuid := gen_random_uuid();
  a_pp uuid; a_n275 uuid; a_n350 uuid; a_c1 uuid; a_c2 uuid; j jsonb; r record; n int;
begin
  select id into ot from offertentyp where name = 'Pooloptionen' and papierkorb_am is null;
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = ot and s.name = 'Gegenstromanlage';
  select ts.id, af.id into ts_a, af_a from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id where ts.arbeitsschritt_id = as_id;
  select id into o175 from auswahloption where auswahlfeld_id = af_a and name = 'EVA 175';
  select id into o225 from auswahloption where auswahlfeld_id = af_a and name = 'EVA 225';
  select id into o275 from auswahloption where auswahlfeld_id = af_a and name = 'EVA 275';
  select id into nisch_es from auswahloption where auswahlfeld_id = af_a and name = 'Nische aus Edelstahl';
  select id into blende_abs from auswahloption where auswahlfeld_id = af_a and name = 'Blende ABS anthrazit';
  select id into blende_es from auswahloption where auswahlfeld_id = af_a and name = 'Blende Edelstahl';
  select id into a_pp from artikel where artikelnummer_knecht = 'AQUASOL_116016';
  select id into a_n275 from artikel where artikelnummer_knecht = 'AQUASOL_116052';
  select id into a_n350 from artikel where artikelnummer_knecht = 'AQUASOL_116053';
  select id into a_c1 from artikel where artikelnummer_knecht = 'AQUASOL_116057';
  select id into a_c2 from artikel where artikelnummer_knecht = 'AQUASOL_116058';
  if as_id is null or ts_a is null or o175 is null or o225 is null or o275 is null or nisch_es is null or blende_abs is null or blende_es is null
     or a_pp is null or a_n275 is null or a_n350 is null or a_c1 is null or a_c2 is null then
    raise exception 'Grundlagen nicht gefunden';
  end if;

  -- InverJet ??? löschen (nur wenn leer)
  delete from auswahloption where auswahlfeld_id = af_a and name = 'InverJet ???' and not exists (select 1 from ressourcenzeile z where z.option_id = auswahloption.id);

  -- Nische (PP) aus den drei Anlagen entfernen, Zeilen nachrücken
  delete from ressourcenzeile where option_id in (o175, o225, o275) and artikel_id = a_pp;
  get diagnostics n = row_count;
  if n <> 3 then raise exception 'Erwartet 3 Nischenzeilen, gelöscht %', n; end if;
  update ressourcenzeile set reihenfolge = reihenfolge - 1 where option_id in (o175, o225, o275) and reihenfolge > 3;
  -- EVA 275: Next 275 statt Next 350
  update ressourcenzeile set artikel_id = a_n275 where option_id = o275 and artikel_id = a_n350;
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Erwartet 1 Turbinenzeile EVA 275, geändert %', n; end if;

  -- Anlagen umbenennen / neu ordnen
  update auswahloption set name = 'EVA 175 Control Eco', reihenfolge = 1,
    beschreibung = 'Gegenstromanlage EVAstream Next 175 mit EVA Control Eco liefern und montieren. Inkl. Kontrolleinheit und Verbindungsschläuche.' where id = o175;
  update auswahloption set name = 'EVA 225 Control 1', reihenfolge = 2,
    beschreibung = 'Gegenstromanlage EVAstream Next 225 mit EVA Control 1 Essential liefern und montieren. Inkl. Kontrolleinheit und Verbindungsschläuche.' where id = o225;
  update auswahloption set name = 'EVA 275 Control 1', reihenfolge = 4,
    beschreibung = 'Gegenstromanlage EVAstream Next 275 mit EVA Control 1 Essential liefern und montieren. Inkl. Kontrolleinheit und Verbindungsschläuche.' where id = o275;

  -- Control-2-Varianten: Kopie von 225 bzw. 275, Controller 116057 -> 116058
  for r in select * from (values
      (o225, o225b, 'EVA 225 Control 2', 3, 'Gegenstromanlage EVAstream Next 225 mit EVA Control 2 Trainer liefern und montieren. Inkl. Kontrolleinheit und Verbindungsschläuche.'),
      (o275, o275b, 'EVA 275 Control 2', 5, 'Gegenstromanlage EVAstream Next 275 mit EVA Control 2 Trainer liefern und montieren. Inkl. Kontrolleinheit und Verbindungsschläuche.')
    ) as v(src, neu, nm, rf, bes)
  loop
    select to_jsonb(x) into j from auswahloption x where x.id = r.src;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j || jsonb_build_object('id', r.neu, 'name', r.nm, 'reihenfolge', r.rf, 'beschreibung', r.bes));
    insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile,
      to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', r.neu,
        'artikel_id', case when z.artikel_id = a_c1 then a_c2 else z.artikel_id end))).*
      from ressourcenzeile z where z.option_id = r.src;
  end loop;

  -- Neue Teilschritte/Auswahlfelder Einbaunische und Blende
  select to_jsonb(t) into j from teilschritt t where t.id = ts_a;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j || jsonb_build_object('id', ts_n, 'name', 'Einbaunische', 'reihenfolge', 2));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j || jsonb_build_object('id', ts_b, 'name', 'Blende', 'reihenfolge', 3));
  select to_jsonb(f) into j from auswahlfeld f where f.id = af_a;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j || jsonb_build_object('id', af_n, 'teilschritt_id', ts_n, 'name', 'Einbaunische', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j || jsonb_build_object('id', af_b, 'teilschritt_id', ts_b, 'name', 'Blende', 'reihenfolge', 1));

  -- Nische Edelstahl verschieben, Minuszeile (PP) entfernen; Nische PP neu
  delete from ressourcenzeile where option_id = nisch_es and artikel_id = a_pp;
  update auswahloption set auswahlfeld_id = af_n, reihenfolge = 2, name = 'Nische aus Edelstahl',
    beschreibung = 'Einbaunische für die Gegenstromanlage aus Edelstahl liefern und einbauen.' where id = nisch_es;
  select to_jsonb(x) into j from auswahloption x where x.id = nisch_es;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j || jsonb_build_object('id', nisch_neu, 'name', 'Nische aus Polypropylen', 'reihenfolge', 1,
    'beschreibung', 'Einbaunische für die Gegenstromanlage aus Polypropylen liefern und einbauen.'));
  insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile,
    to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', nisch_neu, 'artikel_id', a_pp, 'reihenfolge', 1))).*
    from ressourcenzeile z where z.option_id = nisch_es and z.reihenfolge = 1;

  -- Blenden verschieben
  update auswahloption set auswahlfeld_id = af_b, reihenfolge = 1, name = 'Blende ABS anthrazit',
    beschreibung = 'Blende WideX1 Wave aus ABS anthrazit (955 x 335 mm) liefern und montieren.' where id = blende_abs;
  update auswahloption set auswahlfeld_id = af_b, reihenfolge = 2, name = 'Blende Edelstahl',
    beschreibung = 'Blende WideX1 Wave aus Edelstahl (955 x 335 mm) liefern und montieren.' where id = blende_es;

  select count(*) into n from auswahloption where auswahlfeld_id = af_a;
  if n <> 5 then raise exception 'Anlage: erwartet 5 Optionen, %', n; end if;
  select count(*) into n from auswahloption where auswahlfeld_id = af_n;
  if n <> 2 then raise exception 'Nische: erwartet 2 Optionen, %', n; end if;
  select count(*) into n from auswahloption where auswahlfeld_id = af_b;
  if n <> 2 then raise exception 'Blende: erwartet 2 Optionen, %', n; end if;
  select count(*) into n from ressourcenzeile where option_id in (select id from auswahloption where auswahlfeld_id = af_a);
  if n <> 30 then raise exception 'Anlage: erwartet 30 Zeilen (5 x 6), %', n; end if;
end $$;
