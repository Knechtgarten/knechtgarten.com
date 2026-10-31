-- Regenwassertank > Zusatzarbeiten: Teilschritt "Kernbohrung mit Pressring" (Hausdurchführung), Mengenbutton = Anzahl Kernbohrungen.
-- Pro Kernbohrung: Kernbohrgerät 1 Stk. (D 5.5-25 cm), Pressring Einringdichtung U100 für Rohre d63 1 Stk. (wie beim Pool),
-- Polier + Gartenarbeiter je 1.5 Std. Keine Leitungen.
do $$
declare
  as_id uuid; ts_vorlage uuid; af_vorlage uuid; opt_vorlage uuid; ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid(); opt uuid := gen_random_uuid();
  j jsonb; jz jsonb; r record; mx int; n int;
begin
  select s.id into as_id from arbeitsschritt s join offertentyp ot on ot.id = s.offertentyp_id where ot.name = 'Regenwassertank' and ot.papierkorb_am is null and s.name = 'Zusatzarbeiten';
  if as_id is null then raise exception 'Arbeitsschritt Zusatzarbeiten nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name = 'Kernbohrung mit Pressring') then raise exception 'Teilschritt existiert schon'; end if;

  select ts.id, af.id, ao.id into ts_vorlage, af_vorlage, opt_vorlage
    from teilschritt ts join auswahlfeld af on af.teilschritt_id = ts.id join auswahloption ao on ao.auswahlfeld_id = af.id
   where ts.arbeitsschritt_id = as_id and ts.name = 'Schlammsammler montieren' and ao.name = 'Bagger M';
  if opt_vorlage is null then raise exception 'Vorlage Schlammsammler nicht gefunden'; end if;
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt_vorlage and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;
  select max(reihenfolge) into mx from teilschritt where arbeitsschritt_id = as_id;

  select to_jsonb(t) into j from teilschritt t where t.id = ts_vorlage;
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j || jsonb_build_object('id', ts_id, 'name', 'Kernbohrung mit Pressring', 'reihenfolge', mx + 1));
  select to_jsonb(a) into j from auswahlfeld a where a.id = af_vorlage;
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Kernbohrung mit Pressring', 'reihenfolge', 1));
  select to_jsonb(x) into j from auswahloption x where x.id = opt_vorlage;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', 'Kernbohrung mit Pressring', 'reihenfolge', 1,
      'ist_standard', false, 'mehrfachauswahl', false, 'mengenoption', true, 'mengenoption_einheit', 'Stk.', 'mengenoption_standardmenge', 1,
      'hinweistext', 'Menge = Anzahl Kernbohrungen (je Bohrung ein Pressring).',
      'beschreibung', 'Kernbohrung für Hausdurchführung erstellen und mit Pressring abdichten.',
      'optionsgruppe_id', null, 'optionsgruppe_name', null));

  for r in select * from (values
      (1, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000015'), 1.5, 'Std.'),
      (2, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000005'), 1.5, 'Std.'),
      (3, 'maschine', (select id from artikel where artikelnummer_knecht = 'KNECHT_000172'), 1,   'Stk.'),
      (4, 'material', (select id from artikel where artikelnummer_knecht = 'AQUASOL_096203'), 1,   'Stk.')
    ) as v(rf, kat, art, menge, einh)
  loop
    if r.art is null then raise exception 'Artikel für Zeile % nicht gefunden', r.rf; end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat, 'artikel_id', r.art,
        'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh), 'notiz', case r.rf when 1 then 'je Kernbohrung 1.5 Std.' when 2 then 'je Kernbohrung 1.5 Std.' else null end));
  end loop;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 4 then raise exception 'Erwartet 4 Zeilen, angelegt %', n; end if;
end $$;
