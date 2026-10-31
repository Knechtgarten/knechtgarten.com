-- Offertentyp "Naturteich/Schwimmteich" (ENTWURF) mit eingeschaltetem Formen-Tool.
-- Enthält: fünf Systemwerte (Flächen/Umfänge aus dem Code), Konstanten und Formeln, Eingabefelder Wassertiefe/Mauerhöhe,
-- Arbeitsschritte Vorarbeiten, Aushub (Baumaschinen L/M/S, Abtransport), Betonplatte (Kopie Pool-Bodenplatte mit eigenen Werten),
-- Folie und Vlies (Arbeitszeit + Freitext-Positionen, Artikel fehlen im Stamm), Mauern (Natursteinmauer/Kofra als Optionen mit Skizzen-Anhak-Fenster).
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;
create or replace function pg_temp.ref_e(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'eingabefeld') $$;
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.add(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '+', 'args', jsonb_build_array(a, b)) $$;

-- Option mit allen Ressourcenzeilen kopieren; ersatz = {alte_uuid: neue_uuid} wird in den Mengenformeln ersetzt
create or replace function pg_temp.kopiere_option(src uuid, dst_af uuid, nm text, rf int, bes text, ersatz jsonb) returns uuid language plpgsql as $$
declare neu uuid := gen_random_uuid(); j jsonb; jr jsonb; r record; e record; col text;
begin
  select to_jsonb(o) into j from auswahloption o where o.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', neu, 'auswahlfeld_id', dst_af, 'name', nm, 'reihenfolge', rf, 'beschreibung', bes,
      'optionsgruppe_id', null, 'optionsgruppe_name', null, 'tabellenverweis', null, 'auswahlgruppe_id', null, 'ist_standard', false));
  for r in select * from ressourcenzeile where option_id = src order by reihenfolge loop
    jr := to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu);
    foreach col in array array['menge_ausdruck', 'menge_formel_baukasten_ausdruck'] loop
      if jr->col is not null and jsonb_typeof(jr->col) <> 'null' then
        for e in select * from jsonb_each_text(ersatz) loop
          jr := jsonb_set(jr, array[col], replace((jr->col)::text, e.key, e.value)::jsonb);
        end loop;
      end if;
    end loop;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jr);
  end loop;
  return neu;
end $$;

do $$
declare
  ot uuid := gen_random_uuid(); mauern uuid; pool uuid; tank uuid; rf int;
  as_tpl jsonb; ts_tpl jsonb; af_tpl jsonb; op_tpl jsonb; ef_tpl jsonb; jz jsonb;
  e_wt uuid := gen_random_uuid(); e_mh uuid := gen_random_uuid();
  s_ft uuid := gen_random_uuid(); s_ut uuid := gen_random_uuid(); s_ff uuid := gen_random_uuid(); s_uf uuid := gen_random_uuid(); s_fr uuid := gen_random_uuid();
  k_aufbau uuid := gen_random_uuid(); k_mittel uuid := gen_random_uuid(); k_boesch uuid := gen_random_uuid(); k_folzu uuid := gen_random_uuid();
  k_locker uuid := gen_random_uuid(); k_dicke uuid := gen_random_uuid(); k_mager uuid := gen_random_uuid();
  f_atief uuid := gen_random_uuid(); f_arand uuid := gen_random_uuid(); f_atot uuid := gen_random_uuid(); f_alock uuid := gen_random_uuid();
  f_beton uuid := gen_random_uuid(); f_folie uuid := gen_random_uuid(); f_wasser uuid := gen_random_uuid();
  as_id uuid; ts_id uuid; af_id uuid; opt uuid; src_af uuid; n int; x record;
  pool_flaeche uuid := '282c8cd4-9dd6-4829-8f77-6071db7fc941'; pool_beton uuid := 'f610c343-d745-44bd-aa21-4dc0df38d977'; pool_mager uuid := '19b7413f-49e1-4c90-9514-50b67594d5de';
  mauern_aushub uuid := '19c337b9-cfb3-4d05-bed4-5c278d85c7cb';
  polier uuid; garten uuid;
begin
  select id into mauern from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into pool from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  select id into tank from offertentyp where name = 'Regenwassertank' and papierkorb_am is null;
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  if mauern is null or pool is null or tank is null or polier is null or garten is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from offertentyp where name = 'Naturteich/Schwimmteich') then raise exception 'Offertentyp existiert schon'; end if;

  -- Offertentyp
  insert into offertentyp select * from jsonb_populate_record(null::offertentyp,
    (select to_jsonb(o) from offertentyp o where o.id = tank) || jsonb_build_object('id', ot, 'name', 'Naturteich/Schwimmteich', 'formen_aktiv', true, 'ausgeblendet', false, 'papierkorb_am', null,
      'reihenfolge', (select max(reihenfolge) + 1 from offertentyp)));

  -- Eingabefelder
  select to_jsonb(e) into ef_tpl from eingabefeld e where e.offertentyp_id = pool and e.typ = 'zahl' and not e.ist_titel and not e.ist_tabelle order by e.reihenfolge limit 1;
  insert into eingabefeld select * from jsonb_populate_record(null::eingabefeld, ef_tpl || jsonb_build_object('id', e_wt, 'offertentyp_id', ot, 'name', 'Wassertiefe', 'einheit', 'm', 'erklaerung', 'Tiefe der Tiefenzone (bzw. des Teichs ohne Tiefenzone)', 'reihenfolge', 1, 'mindestwert', null, 'fixer_wert', null));
  insert into eingabefeld select * from jsonb_populate_record(null::eingabefeld, ef_tpl || jsonb_build_object('id', e_mh, 'offertentyp_id', ot, 'name', 'Mauerhöhe', 'einheit', 'm', 'erklaerung', 'Höhe der Mauer um die Tiefenzone', 'reihenfolge', 2, 'mindestwert', null, 'fixer_wert', null));

  -- Systemwerte (Flächen/Umfänge aus dem Formen-Tool)
  insert into term (id, offertentyp_id, name, typ, einheit, systemwert_key, reihenfolge, formel_modus) values
    (s_ft, ot, 'Fläche Teichform (laut Formen-Tool)', 'systemwert', 'm²', 'form_flaeche_teich', 1, 'baukasten'),
    (s_ut, ot, 'Umfang Teichform (laut Formen-Tool)', 'systemwert', 'm', 'form_umfang_teich', 2, 'baukasten'),
    (s_ff, ot, 'Fläche Tiefenzone (laut Formen-Tool)', 'systemwert', 'm²', 'form_flaeche_tief', 3, 'baukasten'),
    (s_uf, ot, 'Umfang Tiefenzone (laut Formen-Tool)', 'systemwert', 'm', 'form_umfang_tief', 4, 'baukasten'),
    (s_fr, ot, 'Fläche Randzone (laut Formen-Tool)', 'systemwert', 'm²', 'form_flaeche_rand', 5, 'baukasten');
  -- Konstanten
  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus) values
    (k_aufbau, ot, 'Aufbau Boden Tiefenzone', 'konstante', 0.4, 'm', 6, 'baukasten'),
    (k_mittel, ot, 'Mittelwert Randzone (Tiefe)', 'konstante', 0.5, null, 7, 'baukasten'),
    (k_boesch, ot, 'Böschungsfaktor Folie', 'konstante', 1.15, null, 8, 'baukasten'),
    (k_folzu, ot, 'Folienzuschlag (Faktor)', 'konstante', 1.12, null, 9, 'baukasten'),
    (k_locker, ot, 'Auflockerungsfaktor Aushub', 'konstante', 1.2, null, 10, 'baukasten'),
    (k_dicke, ot, 'Dicke Betonplatte', 'konstante', 0.2, 'm', 11, 'baukasten'),
    (k_mager, ot, 'Dicke Magerbeton', 'konstante', 10, 'cm', 12, 'baukasten');
  -- Formeln (Mengen)
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (f_atief, ot, 'Aushub Tiefenzone (fest)', 'formel', pg_temp.mul(pg_temp.ref_t(s_ff), pg_temp.add(pg_temp.ref_e(e_wt), pg_temp.ref_t(k_aufbau))), 'm³', 13, 'baukasten'),
    (f_arand, ot, 'Aushub Randzone (fest)', 'formel', pg_temp.mul(pg_temp.mul(pg_temp.ref_t(s_fr), pg_temp.ref_e(e_wt)), pg_temp.ref_t(k_mittel)), 'm³', 14, 'baukasten'),
    (f_atot, ot, 'Aushub total (fest)', 'formel', pg_temp.add(pg_temp.ref_t(f_atief), pg_temp.ref_t(f_arand)), 'm³', 15, 'baukasten'),
    (f_alock, ot, 'Volumen Aushub locker total', 'formel', pg_temp.mul(pg_temp.ref_t(f_atot), pg_temp.ref_t(k_locker)), 'm³', 16, 'baukasten'),
    (f_beton, ot, 'Beton Platte Tiefenzone', 'formel', pg_temp.mul(pg_temp.ref_t(s_ff), pg_temp.ref_t(k_dicke)), 'm³', 17, 'baukasten'),
    (f_folie, ot, 'Folienfläche inkl. Zuschlag', 'formel', pg_temp.mul(pg_temp.add(pg_temp.add(pg_temp.ref_t(s_ff), pg_temp.mul(pg_temp.ref_t(s_uf), pg_temp.ref_e(e_mh))), pg_temp.mul(pg_temp.ref_t(s_fr), pg_temp.ref_t(k_boesch))), pg_temp.ref_t(k_folzu)), 'm²', 18, 'baukasten'),
    (f_wasser, ot, 'Wasservolumen', 'formel', pg_temp.add(pg_temp.mul(pg_temp.ref_t(s_ff), pg_temp.ref_e(e_wt)), pg_temp.mul(pg_temp.mul(pg_temp.ref_t(s_fr), pg_temp.ref_e(e_wt)), pg_temp.ref_t(k_mittel))), 'm³', 19, 'baukasten');

  -- Vorlagen für Arbeitsschritt / Teilschritt / Auswahlfeld / Option (aus Mauern > Aushub)
  select to_jsonb(s) into as_tpl from arbeitsschritt s where s.offertentyp_id = mauern and s.name = 'Aushub';
  select to_jsonb(t), to_jsonb(f), to_jsonb(o) into ts_tpl, af_tpl, op_tpl
    from teilschritt t join arbeitsschritt s on s.id = t.arbeitsschritt_id join auswahlfeld f on f.teilschritt_id = t.id join auswahloption o on o.auswahlfeld_id = f.id
   where s.offertentyp_id = mauern and s.name = 'Aushub' and t.name = 'Aushubarbeiten' and o.name = 'Baumaschinen M';
  ts_tpl := ts_tpl || jsonb_build_object('anzeige_term_id', null, 'anzeige_eingabefeld_id', null);
  select to_jsonb(rz) into jz from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = mauern and s.name = 'Aushub' and o.name = 'Baumaschinen M' and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;

  -- 1 Vorarbeiten: Kopie aus Mauern (nur feste Stunden)
  as_id := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'offertentyp_id', ot, 'name', 'Vorarbeiten', 'reihenfolge', 1, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  ts_id := gen_random_uuid(); af_id := gen_random_uuid();
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, ts_tpl || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Ausstecken, vorbereiten', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, af_tpl || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Ausstecken, vorbereiten', 'reihenfolge', 1));
  select o.id into opt from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = mauern and s.name = 'Vorarbeiten' and o.name = 'Ausstecken vorbereiten';
  perform pg_temp.kopiere_option(opt, af_id, 'Ausstecken vorbereiten', 1, (select beschreibung from auswahloption where id = opt), '{}'::jsonb);

  -- 2 Aushub: Baumaschinen L/M/S und Abtransport aus Mauern, Mengenformel auf "Volumen Aushub locker total" dieses Typs umgestellt
  as_id := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'offertentyp_id', ot, 'name', 'Aushub', 'reihenfolge', 2, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  for x in select t.name as tsname, t.reihenfolge as tsrf, t.id as tsid from teilschritt t join arbeitsschritt s on s.id = t.arbeitsschritt_id where s.offertentyp_id = mauern and s.name = 'Aushub' order by t.reihenfolge loop
    ts_id := gen_random_uuid(); af_id := gen_random_uuid();
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt, (select to_jsonb(t) from teilschritt t where t.id = x.tsid) || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'anzeige_term_id', null, 'anzeige_eingabefeld_id', null));
    select f.id into src_af from auswahlfeld f where f.teilschritt_id = x.tsid;
    insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, (select to_jsonb(f) from auswahlfeld f where f.id = src_af) || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id));
    rf := 0;
    for opt in select o.id from auswahloption o where o.auswahlfeld_id = src_af and o.name in ('Baumaschinen L', 'Baumaschinen M', 'Baumaschinen S', 'Abtransport Mulde LKW', 'Abtransport Lieferwagen') order by o.reihenfolge loop
      rf := rf + 1;
      perform pg_temp.kopiere_option(opt, af_id, (select name from auswahloption where id = opt), rf, (select beschreibung from auswahloption where id = opt), jsonb_build_object(mauern_aushub::text, f_alock::text));
    end loop;
  end loop;

  -- 3 Betonplatte Tiefenzone: Kopie "Bodenplatte armiert" aus dem Pool, Mengen auf Fläche Tiefenzone / Beton Platte / Magerbeton umgestellt
  as_id := gen_random_uuid(); ts_id := gen_random_uuid(); af_id := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'offertentyp_id', ot, 'name', 'Betonplatte Tiefenzone', 'reihenfolge', 3, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, ts_tpl || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Bodenplatte', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, af_tpl || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Bodenplatte', 'reihenfolge', 1));
  select o.id into opt from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = pool and o.name = 'Bodenplatte armiert' limit 1;
  perform pg_temp.kopiere_option(opt, af_id, 'Bodenplatte armiert', 1, 'Betonplatte für die Tiefenzone mit Armierung erstellen.',
    jsonb_build_object(pool_flaeche::text, s_ff::text, pool_beton::text, f_beton::text, pool_mager::text, k_mager::text));

  -- 4 Folie und Vlies: Arbeitszeit je m2 Folie, Folie und Vlies als Freitext-Positionen (Artikel fehlen im Artikelstamm)
  as_id := gen_random_uuid(); ts_id := gen_random_uuid(); af_id := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'offertentyp_id', ot, 'name', 'Folie und Vlies', 'reihenfolge', 4, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, ts_tpl || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Teichfolie', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, af_tpl || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Teichfolie', 'reihenfolge', 1));
  opt := gen_random_uuid();
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, op_tpl || jsonb_build_object('id', opt, 'auswahlfeld_id', af_id, 'name', 'Teichfolie verlegen', 'reihenfolge', 1,
    'beschreibung', 'Schutzvlies und Teichfolie liefern, verlegen und an den Rändern sauber ausbilden.', 'hinweistext', 'Folie und Vlies sind Freitext-Positionen: Menge (Folienfläche) und Preis eintragen.',
    'mengenoption', false, 'mehrfachauswahl', false, 'optionsgruppe_id', null, 'optionsgruppe_name', null, 'tabellenverweis', null, 'auswahlgruppe_id', null));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1, 'kategorie', 'personal', 'artikel_id', polier,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(f_folie), jsonb_build_object('lit', 0.15, '_einheit', 'Std.'))));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 2, 'kategorie', 'personal', 'artikel_id', garten,
    'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(f_folie), jsonb_build_object('lit', 0.15, '_einheit', 'Std.'))));
  insert into option_freitext_vorlage (option_id, kategorie, bezeichnung, einheit, menge_vorschlag, preis_vorschlag, reihenfolge, ist_eigene_offertenposition) values
    (opt, 'material', 'Teichfolie EPDM (Artikel fehlt im Artikelstamm, Menge und Preis eintragen)', 'm²', 1, null, 3, false),
    (opt, 'material', 'Schutzvlies (Artikel fehlt im Artikelstamm, Menge und Preis eintragen)', 'm²', 1, null, 4, false);

  -- 5 Mauern: Natursteinmauer und Kofra als Optionen mit Skizzen-Anhak-Fenster (Tabellenverweis "Formen-Tool: Tiefenzone")
  as_id := gen_random_uuid(); ts_id := gen_random_uuid(); af_id := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'offertentyp_id', ot, 'name', 'Mauern', 'reihenfolge', 5, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, ts_tpl || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Mauer um die Tiefenzone', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, af_tpl || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Mauerart', 'reihenfolge', 1));
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, op_tpl || jsonb_build_object('id', gen_random_uuid(), 'auswahlfeld_id', af_id, 'name', 'Natursteinmauer', 'reihenfolge', 1,
    'beschreibung', 'Natursteinmauer als Abgrenzung der Tiefenzone, Ausführung gemäss separater Mauer-Offerte.', 'hinweistext', 'Beim Anklicken öffnet sich die Skizze: Umfangsstücke der Tiefenzone anhaken.',
    'mengenoption', false, 'mehrfachauswahl', true, 'optionsgruppe_id', null, 'optionsgruppe_name', null, 'auswahlgruppe_id', null,
    'tabellenverweis', jsonb_build_array(jsonb_build_object('eingabefeld_id', 'formen:tief', 'spalte_id', 'laenge'))));
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption, op_tpl || jsonb_build_object('id', gen_random_uuid(), 'auswahlfeld_id', af_id, 'name', 'Kofra', 'reihenfolge', 2,
    'beschreibung', 'Betonmauer (Kofra) als Abgrenzung der Tiefenzone, Ausführung gemäss separater Mauer-Offerte.', 'hinweistext', 'Nur gerade Umfangsstücke wählbar.',
    'mengenoption', false, 'mehrfachauswahl', true, 'optionsgruppe_id', null, 'optionsgruppe_name', null, 'auswahlgruppe_id', null,
    'tabellenverweis', jsonb_build_array(jsonb_build_object('eingabefeld_id', 'formen:tief', 'spalte_id', 'gerade'))));

  -- Kontrolle: keine Formel verweist auf Werte anderer Offertentypen
  select count(*) into n from (
    select distinct (regexp_matches(rz.menge_ausdruck::text, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'g'))[1] as id
      from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
     where s.offertentyp_id = ot) chk
   where chk.id not in (select id::text from term where offertentyp_id = ot or offertentyp_id is null union select id::text from eingabefeld where offertentyp_id = ot);
  if n > 0 then raise exception 'Es gibt % Verweise auf Werte anderer Offertentypen', n; end if;
end $$;
