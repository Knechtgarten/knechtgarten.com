-- Pooloptionen: neuer Arbeitsschritt "Duschen" (nach "Plattenbelag Poolboden") mit den zwei Aquasolar-Duschen.
-- Vorerst nur die Dusche als Material (1 Stk.); Montage und Fundament folgen.
do $$
declare
  ot uuid; as_vorlage uuid; ts_vorlage uuid; af_vorlage uuid; opt_vorlage uuid; as_neu uuid := gen_random_uuid(); ts_neu uuid := gen_random_uuid(); af_neu uuid := gen_random_uuid();
  jz jsonb; j jsonb; r record; opt uuid; mx int; n int;
begin
  select id into ot from offertentyp where name = 'Pooloptionen' and papierkorb_am is null;
  select s.id, ts.id, af.id, ao.id into as_vorlage, ts_vorlage, af_vorlage, opt_vorlage
    from arbeitsschritt s join teilschritt ts on ts.arbeitsschritt_id = s.id join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption ao on ao.auswahlfeld_id = af.id
   where s.offertentyp_id = ot and s.name = 'Wärmepumpe (ohne Grabarbeiten)' and ao.name = 'WP-30m3';
  if ot is null or opt_vorlage is null then raise exception 'Vorlage nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Duschen') then raise exception 'Duschen gibt es schon'; end if;
  select max(reihenfolge) into mx from arbeitsschritt where offertentyp_id = ot;
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt_vorlage and rz.kategorie = 'material' order by rz.reihenfolge limit 1;

  select to_jsonb(s) into j from arbeitsschritt s where s.id = as_vorlage;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, j || jsonb_build_object('id', as_neu, 'name', 'Duschen', 'reihenfolge', mx + 1, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  select to_jsonb(t) into j from teilschritt t where t.id = ts_vorlage;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j || jsonb_build_object('id', ts_neu, 'arbeitsschritt_id', as_neu, 'name', 'Dusche', 'reihenfolge', 1, 'beschreibung', null));
  select to_jsonb(a) into j from auswahlfeld a where a.id = af_vorlage;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', 'Dusche', 'reihenfolge', 1));

  for r in select * from (values
      (1, 'Norderney (Fussbrause)', 'Dusche Norderney Typ EHM Modell 70 aus Edelstahl V4A mit Fussbrause liefern und montieren.', 'Norderney Typ EHM Modell 70, Edelstahl V4A, mit Kopfbrause und Fussbrause.', 'AQUASOL_163021'),
      (2, 'Sylt (Handbrause)',      'Dusche Sylt Typ EHM Modell 70 aus Edelstahl V4A mit Handbrause liefern und montieren.',    'Sylt Typ EHM Modell 70, Edelstahl V4A, mit Handbrause.',                         'AQUASOL_163024')
    ) as v(rf, nm, bes, hinw, art)
  loop
    opt := gen_random_uuid();
    select to_jsonb(x) into j from auswahloption x where x.id = opt_vorlage;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_neu, 'name', r.nm, 'reihenfolge', r.rf, 'beschreibung', r.bes, 'hinweistext', r.hinw,
        'ist_standard', false, 'mehrfachauswahl', false, 'mengenoption', false, 'mengenoption_einheit', 'Stk.', 'mengenoption_standardmenge', null,
        'optionsgruppe_id', null, 'optionsgruppe_name', null, 'tabellenverweis', null));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'kategorie', 'material',
        'artikel_id', (select id from artikel where artikelnummer_knecht = r.art), 'menge_ausdruck', '{"lit": 1, "_einheit": "Stk."}'::jsonb, 'notiz', null));
  end loop;
  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id where ao.auswahlfeld_id = af_neu and rz.artikel_id is not null;
  if n <> 2 then raise exception 'Erwartet 2 Zeilen mit Artikel, angelegt %', n; end if;
end $$;
