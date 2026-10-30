-- Regenwassertank > Zusatzarbeiten: neuer Teilschritt "Wasserzapfsaeule montieren" (Zusatzoption, Anzahl Saeulen)
-- Pro Saeule: Wasserzapfsaeule Edelstahl 1 Stk., 2 Sack Gartenbeton (25 kg), Polier 3 Std. + Gartenarbeiter 3 Std.
do $$
declare
  as_id uuid; ts_vorlage uuid; af_vorlage uuid; opt_vorlage uuid;
  ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid(); opt uuid := gen_random_uuid();
  j jsonb; jz jsonb; r record; n int;
begin
  select s.id into as_id from arbeitsschritt s where s.offertentyp_id = '35764680-9e7a-480a-b765-7a8fe488b054' and s.name = 'Zusatzarbeiten';
  if as_id is null then raise exception 'Arbeitsschritt Zusatzarbeiten nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Wasserzapfsäule montieren') then raise exception 'Teilschritt existiert schon'; end if;

  select ts.id, af.id, ao.id into ts_vorlage, af_vorlage, opt_vorlage
    from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption ao on ao.auswahlfeld_id = af.id
   where ts.arbeitsschritt_id = as_id and ao.name = 'Bagger M';
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt_vorlage and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;

  select to_jsonb(t) into j from teilschritt t where t.id = ts_vorlage;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
    j || jsonb_build_object('id', ts_id, 'name', 'Wasserzapfsäule montieren', 'reihenfolge', 3));
  select to_jsonb(a) into j from auswahlfeld a where a.id = af_vorlage;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
    j || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Wasserzapfsäule', 'reihenfolge', 1));
  select to_jsonb(o) into j from auswahloption o where o.id = opt_vorlage;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', 'Wasserzapfsäule montieren', 'reihenfolge', 1,
      'ist_standard', false, 'mehrfachauswahl', true, 'mengenoption', true, 'mengenoption_einheit', 'Stk.',
      'mengenoption_standardmenge', 1, 'hinweistext', 'Menge = Anzahl Wasserzapfsäulen', 'optionsgruppe_id', null, 'optionsgruppe_name', null,
      'beschreibung', 'Wasserzapfsäule liefern und montieren. Inkl. Fundament mit Fertigbeton.'));

  for r in select * from (values
      (1, 'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a'::uuid, 3, 'Std.'),   -- Polier / Vorarbeiter
      (2, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81'::uuid, 3, 'Std.'),   -- Gartenarbeiter
      (3, 'material', '36ef6751-f28d-40ae-a45a-eb3c0cebe70b'::uuid, 1, 'Stk.'),   -- Wasserzapfsaeule Edelstahl
      (4, 'material', 'ad4c79b9-13fc-4660-a912-6d21f678bbfe'::uuid, 2, 'Stk.')    -- MAXIMUM GIARDINO 016 Universal-Gartenbeton 25 kg
    ) as v(rf, kat, art, menge, einh)
  loop
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat,
        'artikel_id', r.art, 'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh)));
  end loop;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 4 then raise exception 'Erwartet 4 Zeilen, angelegt %', n; end if;
end $$;
