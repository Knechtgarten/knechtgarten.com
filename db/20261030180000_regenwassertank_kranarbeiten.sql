-- Regenwassertank > Zusatzarbeiten: neuer Teilschritt "Kranarbeiten" mit Optionsgruppe "Kranarbeiten"
-- (je Krangroesse eine Option, schliessen sich aus). Pro Einsatz (= pro Tank): Kran 3 Std. (inkl. Hin-/Rueckfahrt),
-- Polier 2 Std. + Gartenarbeiter 2 Std. fuer das Versetzen.
do $$
declare
  as_id uuid; ts_vorlage uuid; af_vorlage uuid; opt_vorlage uuid;
  ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid(); g uuid := gen_random_uuid();
  j jsonb; jz jsonb; r record; opt uuid; n int;
begin
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = '35764680-9e7a-480a-b765-7a8fe488b054' and s.name = 'Zusatzarbeiten';
  if as_id is null then raise exception 'Arbeitsschritt Zusatzarbeiten nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Kranarbeiten') then raise exception 'Teilschritt Kranarbeiten existiert schon'; end if;

  select ts.id, af.id, ao.id into ts_vorlage, af_vorlage, opt_vorlage
    from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption ao on ao.auswahlfeld_id = af.id
   where ts.arbeitsschritt_id = as_id and ao.name = 'Bagger M';
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt_vorlage and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;

  select to_jsonb(t) into j from teilschritt t where t.id = ts_vorlage;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
    j || jsonb_build_object('id', ts_id, 'name', 'Kranarbeiten', 'reihenfolge', 2));
  select to_jsonb(a) into j from auswahlfeld a where a.id = af_vorlage;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
    j || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Kranarbeiten', 'reihenfolge', 1));

  for r in select * from (values
      (1, '3-Achs (15 m)',        'bfad849d-774a-418e-a887-da27731db147'::uuid),
      (2, '3-Achs Sattel (20 m)', '6beb1575-7e95-438b-9178-c4e4a2229e61'::uuid),
      (3, '4-Achs (20 m)',        'a5bed9ba-819f-4a36-aebf-9515ccef7a01'::uuid),
      (4, '5-Achs (27 m)',        '8fb48a96-12e6-4d27-a68d-b8ed4416ac75'::uuid),
      (5, '5-Achs Spezial (31 m)','dbb4d8d8-5f3d-4589-8a77-1622a9339548'::uuid),
      (6, 'Pneukran MK 88',       'fe1447f8-ac70-493a-97e9-6313467e0d26'::uuid)
    ) as v(rf, nm, kran)
  loop
    opt := gen_random_uuid();
    select to_jsonb(o) into j from auswahloption o where o.id = opt_vorlage;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', r.nm, 'reihenfolge', r.rf,
        'ist_standard', false, 'mehrfachauswahl', false, 'mengenoption', false, 'mengenoption_einheit', 'Stk.',
        'mengenoption_standardmenge', null, 'hinweistext', null,
        'beschreibung', 'Regenwassertank mit Kranwagen versetzen. Inkl. Hin- und Rückfahrt des Krans.',
        'optionsgruppe_id', g, 'optionsgruppe_name', 'Kranarbeiten'));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'kategorie', 'personal',
        'artikel_id', '8fa14723-4de8-4395-a50a-4f72c11e9a7a', 'menge_ausdruck', '{"lit": 2, "_einheit": "Std."}'::jsonb));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 2, 'kategorie', 'personal',
        'artikel_id', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', 'menge_ausdruck', '{"lit": 2, "_einheit": "Std."}'::jsonb));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 3, 'kategorie', 'logistik',
        'artikel_id', r.kran, 'menge_ausdruck', '{"lit": 3, "_einheit": "Std."}'::jsonb));
  end loop;

  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id where ao.auswahlfeld_id = af_id;
  if n <> 18 then raise exception 'Erwartet 18 Zeilen, angelegt %', n; end if;
end $$;
