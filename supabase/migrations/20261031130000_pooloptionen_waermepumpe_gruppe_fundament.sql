-- Pooloptionen > Wärmepumpe: WP-30 bis WP-80 m3 als Optionsgruppe "Wärmepumpe" (ein Button mit Dropdown in Tool A),
-- neue Zusatzoption "Zusatz: Fundament Wärmepumpe" (kombinierbar, Mehrfachauswahl):
-- 1 FINALGO Vakuum Stellplatte 100x6x60 cm, 0.1 m3 Splitt 4/8, 0.1 m3 Abfuhr (Deponie), Polier 1.5 Std. + Gartenarbeiter 1.5 Std.
do $$
declare
  af_id uuid; vorlage uuid; wp30 uuid; g uuid := gen_random_uuid(); opt uuid := gen_random_uuid(); jz jsonb; j jsonb; r record; n int;
begin
  select ao.auswahlfeld_id, ao.id into af_id, wp30 from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Wärmepumpe (ohne Grabarbeiten)' and ao.name = 'WP-30m3';
  select ao.id into vorlage from auswahloption ao where ao.auswahlfeld_id = af_id and ao.name = 'Zusatz: isolierte Leitungen pro/ml';
  if af_id is null or vorlage is null then raise exception 'Wärmepumpe-Optionen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name = 'Zusatz: Fundament Wärmepumpe') then raise exception 'Fundament-Zusatz existiert schon'; end if;

  update auswahloption set optionsgruppe_id = g, optionsgruppe_name = 'Wärmepumpe'
   where auswahlfeld_id = af_id and name like 'WP-%m3' and mehrfachauswahl = false;
  get diagnostics n = row_count;
  if n <> 5 then raise exception 'Erwartet 5 Wärmepumpen für die Gruppe, gefunden %', n; end if;

  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = wp30 and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;
  select to_jsonb(x) into j from auswahloption x where x.id = vorlage;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'name', 'Zusatz: Fundament Wärmepumpe', 'reihenfolge', 8, 'mehrfachauswahl', true, 'ist_standard', false,
      'mengenoption', false, 'mengenoption_einheit', 'Stk.', 'mengenoption_standardmenge', null, 'optionsgruppe_id', null, 'optionsgruppe_name', null,
      'beschreibung', 'Fundament für die Wärmepumpe erstellen: Stellplatte auf Splittbett versetzen.',
      'hinweistext', 'Inkl. Stellplatte FINALGO Vakuum 100x6x60 cm, Splittbett und Abfuhr des Aushubs.'));

  for r in select * from (values
      (1, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000015'), 1.5, 'Std.'),
      (2, 'personal', (select id from artikel where artikelnummer_knecht = 'KNECHT_000005'), 1.5, 'Std.'),
      (3, 'material', (select id from artikel where artikelnummer_knecht = 'HGC_100112376'),  1,   'Stk.'),
      (4, 'material', (select id from artikel where artikelnummer_knecht = 'KIEHEIM_511'),    0.1, 'm³'),
      (5, 'material', 'e08b2087-b590-4f3a-bbc0-c83520cc1e24'::uuid,                           0.1, 'm³')
    ) as v(rf, kat, art, menge, einh)
  loop
    if r.art is null then raise exception 'Artikel für Zeile % nicht gefunden', r.rf; end if;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', r.rf, 'kategorie', r.kat, 'artikel_id', r.art,
        'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh), 'notiz', null));
  end loop;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 5 then raise exception 'Erwartet 5 Zeilen, angelegt %', n; end if;
end $$;
