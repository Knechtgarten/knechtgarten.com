-- Regenwassertank > Zusatzarbeiten: Teilschritt "Schlammsammler montieren", Optionsgruppe "Schlammsammler" (Bagger S/M/L)
-- Pro Schlammsammler: Betonrohr mit Boden Ø50 H105 1 Stk., 2 Forsheda-Dichtungen, 2 Kernbohrungen (D 5.5-25 cm),
-- 1 m3 Aushub (Deponie), Polier 4 Std. + Gartenarbeiter 4 Std., Bagger 2 Std.
do $$
declare
  as_id uuid; ts_vorlage uuid; af_vorlage uuid; opt_vorlage uuid;
  ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid(); g uuid := gen_random_uuid();
  j jsonb; jz jsonb; o record; r record; opt uuid; n int;
begin
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = '35764680-9e7a-480a-b765-7a8fe488b054' and s.name = 'Zusatzarbeiten';
  if as_id is null then raise exception 'Arbeitsschritt Zusatzarbeiten nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Schlammsammler montieren') then raise exception 'Teilschritt existiert schon'; end if;

  select ts.id, af.id, ao.id into ts_vorlage, af_vorlage, opt_vorlage
    from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption ao on ao.auswahlfeld_id = af.id
   where ts.arbeitsschritt_id = as_id and ao.name = 'Bagger M';
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt_vorlage and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;

  select to_jsonb(t) into j from teilschritt t where t.id = ts_vorlage;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
    j || jsonb_build_object('id', ts_id, 'name', 'Schlammsammler montieren', 'reihenfolge', 4));
  select to_jsonb(a) into j from auswahlfeld a where a.id = af_vorlage;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
    j || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Schlammsammler montieren', 'reihenfolge', 1));

  for o in select * from (values (1, 'Bagger S', '2e2323d0-3244-4158-99c1-dd54a0e099f9'::uuid), (2, 'Bagger M', 'f5cad0dd-3699-4dcf-bce1-f644825b7a98'::uuid), (3, 'Bagger L', 'bf15228b-109a-449a-b67c-086a711dd27a'::uuid)) as v(rf, nm, bagger)
  loop
    opt := gen_random_uuid();
    select to_jsonb(x) into j from auswahloption x where x.id = opt_vorlage;
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
      j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', o.nm, 'reihenfolge', o.rf,
        'ist_standard', false, 'mehrfachauswahl', false, 'mengenoption', true, 'mengenoption_einheit', 'Stk.',
        'mengenoption_standardmenge', 1, 'hinweistext', 'Menge = Anzahl Schlammsammler',
        'beschreibung', 'Schlammsammler liefern und montieren. Inkl. Aushub und Entsorgung, Kernbohrungen und Dichtungen für die Anschlüsse.',
        'optionsgruppe_id', g, 'optionsgruppe_name', 'Schlammsammler'));
    for r in select * from (values
        (1, 'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a'::uuid, 4, 'Std.'),   -- Polier / Vorarbeiter
        (2, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81'::uuid, 4, 'Std.'),   -- Gartenarbeiter
        (3, 'material', '6636363a-ffe7-4b36-8741-baaf070fa917'::uuid, 1, 'Stk.'),   -- Betonrohr mit Boden unbewehrt Ø50 H105
        (4, 'material', '31fe7875-19b3-4e34-819b-ed6d14d35bf0'::uuid, 2, 'Stk.'),   -- Forsheda Dichtung Ø110/138
        (5, 'maschine', '54133ccc-fe2b-44da-a5c4-b2c913925950'::uuid, 2, 'Stk.'),   -- Kernbohrgerät pro Bohrung D 5.5-25 cm
        (6, 'material', 'e08b2087-b590-4f3a-bbc0-c83520cc1e24'::uuid, 1, 'm³'),     -- Deponiegebuehren Mat. getrennt, Direktfuhre
        (7, 'maschine', o.bagger,                                     2, 'Std.')     -- Raupenbagger S/M/L
      ) as v(rf, kat, art, menge, einh)
    loop
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
        jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat,
          'artikel_id', r.art, 'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh)));
    end loop;
  end loop;

  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id where ao.auswahlfeld_id = af_id;
  if n <> 21 then raise exception 'Erwartet 21 Zeilen, angelegt %', n; end if;
end $$;
