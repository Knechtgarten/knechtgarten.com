-- Pooloptionen > Duschen: dritte Dusche "Juist" (AQUASOL_163022), Montage in allen drei Duschen (Polier 2 Std. + Gartenarbeiter 2 Std.),
-- neue Zusatzoption "Zusatz: Fundament Dusche": Bodenelement Edelstahl (Grütter Metallwaren, Platzhalterpreis CHF 350) + 2 Sack Gartenbeton.
do $$
declare
  af_id uuid; vorlage uuid; gr uuid; boden uuid; beton uuid; polier uuid; garten uuid; juist uuid; opt uuid; fund uuid := gen_random_uuid();
  j jsonb; jz jsonb; o record; r record; n int;
begin
  select ao.auswahlfeld_id, ao.id into af_id, vorlage from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Duschen' and ao.name = 'Sylt (Handbrause)';
  select id into gr from lieferant where name = 'Grütter Metallwaren AG';
  select id into juist from artikel where artikelnummer_knecht = 'AQUASOL_163022';
  select id into beton from artikel where artikelnummer_knecht = 'HGC_100115789';
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  if af_id is null or gr is null or juist is null or beton is null or polier is null or garten is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name like 'Juist%') then raise exception 'Juist existiert schon'; end if;

  -- Bodenelement (Platzhalterpreis)
  boden := gen_random_uuid();
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (boden, gr, 'material', 'GRTTER_BODENELEMENT_DUSCHE', 'GRTTER_BODENELEMENT_DUSCHE', 'Bodenelement Edelstahl für Dusche', 'Stk.', null, 350, 'CHF', 1, 8.1,
          'Platzhalterpreis CHF 350 (Verkauf), noch nicht bei Grütter Metallwaren bestätigt.', false, false, false, true, false);

  -- Dritte Dusche: Kopie von Sylt, dann Zeilen aller drei Duschen neu aufbauen
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = vorlage and rz.kategorie = 'material' order by rz.reihenfolge limit 1;
  opt := gen_random_uuid();
  select to_jsonb(x) into j from auswahloption x where x.id = vorlage;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt, 'name', 'Juist (Handbrause)', 'reihenfolge', 3,
      'beschreibung', 'Dusche Juist Typ EHM Modell 70 aus Edelstahl V4A mit Handbrause liefern und montieren.',
      'hinweistext', 'Juist Typ EHM Modell 70, Edelstahl V4A, mit Handbrause.'));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'kategorie', 'material', 'artikel_id', juist, 'menge_ausdruck', '{"lit": 1, "_einheit": "Stk."}'::jsonb));

  for o in select ao.id from auswahloption ao where ao.auswahlfeld_id = af_id and ao.name in ('Norderney (Fussbrause)', 'Sylt (Handbrause)', 'Juist (Handbrause)') loop
    update ressourcenzeile set reihenfolge = 3 where option_id = o.id and kategorie = 'material';
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', o.id,
      'reihenfolge', 1, 'kategorie', 'personal', 'artikel_id', polier, 'menge_ausdruck', '{"lit": 2, "_einheit": "Std."}'::jsonb, 'notiz', 'Montage der Dusche'));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', o.id,
      'reihenfolge', 2, 'kategorie', 'personal', 'artikel_id', garten, 'menge_ausdruck', '{"lit": 2, "_einheit": "Std."}'::jsonb, 'notiz', 'Montage der Dusche'));
  end loop;

  -- Zusatz: Fundament
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', fund, 'name', 'Zusatz: Fundament Dusche', 'reihenfolge', 4, 'mehrfachauswahl', true,
      'beschreibung', 'Fundament für die Dusche erstellen: Bodenelement Edelstahl einbetonieren.',
      'hinweistext', 'Inkl. Bodenelement Edelstahl und Fertigbeton.'));
  for r in select * from (values (1, boden, 1, 'Stk.'), (2, beton, 2, 'Stk.')) as v(rf, art, menge, einh) loop
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', fund, 'reihenfolge', r.rf, 'kategorie', 'material', 'artikel_id', r.art,
        'menge_ausdruck', jsonb_build_object('lit', r.menge, '_einheit', r.einh)));
  end loop;

  select count(*) into n from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id where ao.auswahlfeld_id = af_id;
  if n <> 11 then raise exception 'Erwartet 11 Zeilen (3 x 3 + 2), gefunden %', n; end if;
end $$;
