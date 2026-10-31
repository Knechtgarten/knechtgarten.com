-- Naturteich/Schwimmteich: Technik aus dem Pool übernommen (Kopien der gelb markierten Optionen) und Betonstellriemen (leichte Variante des Betonkragens).
--  Arbeitsschritte neu: 7 Betonstellriemen, 8 Verrohrung Übergabepunkt-Technikstandort, 9 Teichtechnik (Filtration, Umwälzpumpe),
--  10 Technik Boxen, Schränke, Schächte (nur Typ. Vliesfilter), 11 Einbauteile (Skimmer, Düsen/Bodenablauf, Unterwasserbeleuchtung).
--  Betonstellriemen: Kopie von "Betonkragen LW" und "Betonkragen LKW gepumpt", Länge = Umfang Tiefenzone, Betonquerschnitt halb so gross
--  wie der Betonkragen (0.25 m x 0.30 m / 2 = 0.0375 m2), Schalungszeit (Meterzeit) halbiert; Betonier-Zeit halbiert sich über das Volumen.
--  Die Randschiene wird als Zusatz bei der Folie entfernt (sie gehört nur zu Kofra).
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;

create or replace function pg_temp.kopiere_option(src uuid, dst_af uuid, nm text, rf int, bes text, ersatz jsonb) returns uuid language plpgsql as $$
declare neu uuid := gen_random_uuid(); j jsonb; jr jsonb; r record; e record; col text; f record;
begin
  select to_jsonb(o) into j from auswahloption o where o.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', neu, 'auswahlfeld_id', dst_af, 'name', nm, 'reihenfolge', rf, 'beschreibung', coalesce(bes, j->>'beschreibung'),
      'optionsgruppe_id', null, 'optionsgruppe_name', null, 'auswahlgruppe_id', null, 'ist_standard', false));
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
  for f in select * from option_freitext_vorlage where option_id = src loop
    insert into option_freitext_vorlage select * from jsonb_populate_record(null::option_freitext_vorlage, to_jsonb(f) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu));
  end loop;
  return neu;
end $$;

do $$
declare
  ot uuid; pool uuid; as_tpl jsonb; s_uf uuid; k_stell uuid := gen_random_uuid(); t_laenge uuid := gen_random_uuid(); t_vol uuid := gen_random_uuid();
  polier uuid; garten uuid; plan record; as_id uuid; ts_id uuid; af_id uuid; src_ts uuid; src_af uuid; o record; rf int; neu uuid; n int; opt_namen text[];
  pool_laenge uuid := 'ffe57f9f-8ba8-4b7a-b0e5-e4de7c22f6c3'; pool_vol uuid := 'bcc771d9-77a4-4530-aecf-de19463e485f';
  stell_opts uuid[] := '{}';
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select id into pool from offertentyp where name = 'Pool/Wassergarten' and papierkorb_am is null;
  select id into s_uf from term where offertentyp_id = ot and systemwert_key = 'form_umfang_tief';
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  select to_jsonb(s) into as_tpl from arbeitsschritt s where s.offertentyp_id = ot and s.name = 'Mauern';
  if ot is null or pool is null or s_uf is null or as_tpl is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Betonstellriemen') then raise exception 'Schon vorhanden'; end if;

  -- Werte für den Betonstellriemen
  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus) values (k_stell, ot, 'Querschnitt Betonstellriemen', 'konstante', 0.0375, 'm²', 34, 'baukasten');
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (t_laenge, ot, 'Länge Betonstellriemen', 'formel', pg_temp.ref_t(s_uf), 'm', 35, 'baukasten'),
    (t_vol, ot, 'Volumen Betonstellriemen', 'formel', pg_temp.mul(pg_temp.ref_t(t_laenge), pg_temp.ref_t(k_stell)), 'm³', 36, 'baukasten');

  -- Pläne: neuer Arbeitsschritt, Pool-Arbeitsschritt, Pool-Teilschritt, Optionen (Muster), Reihenfolge des Arbeitsschritts
  for plan in select * from (values
      (7,  'Betonstellriemen', 'Betonkragen und Hinterfüllung', 'Betonkragen', array['Betonkragen LW', 'Betonkragen LKW gepumpt']),
      (8,  'Verrohrung Übergabepunkt-Technikstandort', 'Verrohrung Übergabepunkt-Technikstandort (inkl. Grabarbeiten)', 'Verrohrung Übergabepunkt-Technikstandort', array['Grabarbeiten Tageseinsatz', '1 - 3 Leitungen']),
      (9,  'Teichtechnik', 'Pooltechnik', 'Filtration', array['Vliesfilter', 'Kompaktfilter Bio']),
      (9,  'Teichtechnik', 'Pooltechnik', 'Umwälzpumpe', array['Inv. Master 30', 'Kobre Tec 20%12V', 'Wasserspiel 5000', 'Wasserspiel 3000']),
      (10, 'Technik Boxen, Schränke, Schächte', 'Technik Boxen, Schränke, Schächte', 'Techniklokal', array['Typ. Vliesfilter']),
      (11, 'Einbauteile', 'Einbauteile', 'Skimmer', array['Fiap BIO', 'Filterskimmer Bio']),
      (11, 'Einbauteile', 'Einbauteile', 'Düsen, Flansche, Bodenablauf', array['Einlaufdüse', 'Bodenablauf']),
      (11, 'Einbauteile', 'Einbauteile', 'Unterwasserbeleuchtung', array['EVA A25', 'EVA A40', 'EVA S10'])
    ) as v(rf, neu_as, pool_as, pool_ts, opts)
  loop
    select id into as_id from arbeitsschritt where offertentyp_id = ot and name = plan.neu_as;
    if as_id is null then
      as_id := gen_random_uuid();
      insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'name', plan.neu_as, 'reihenfolge', plan.rf, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));
    end if;
    select t.id into src_ts from teilschritt t join arbeitsschritt s on s.id = t.arbeitsschritt_id where s.offertentyp_id = pool and s.name = plan.pool_as and t.name = plan.pool_ts;
    select f.id into src_af from auswahlfeld f where f.teilschritt_id = src_ts;
    if src_ts is null or src_af is null then raise exception 'Pool-Teilschritt % / % nicht gefunden', plan.pool_as, plan.pool_ts; end if;
    ts_id := gen_random_uuid(); af_id := gen_random_uuid();
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt, (select to_jsonb(t) from teilschritt t where t.id = src_ts) ||
      jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'anzeige_term_id', null, 'anzeige_eingabefeld_id', null,
        'reihenfolge', coalesce((select max(reihenfolge) from teilschritt where arbeitsschritt_id = as_id), 0) + 1));
    insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, (select to_jsonb(f) from auswahlfeld f where f.id = src_af) || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id));
    rf := 0;
    for o in select ao.id, ao.name, ao.beschreibung from auswahloption ao where ao.auswahlfeld_id = src_af and ao.name like any(plan.opts) order by ao.reihenfolge loop
      rf := rf + 1;
      if plan.neu_as = 'Betonstellriemen' then
        neu := pg_temp.kopiere_option(o.id, af_id,
          case o.name when 'Betonkragen LW' then 'Betonstellriemen Lieferwagen' else 'Betonstellriemen LKW gepumpt' end, rf,
          case o.name when 'Betonkragen LW' then 'Leichten Betonstellriemen (25 cm hoch) für die Mauer erstellen, Beton per Lieferwagen angeliefert.'
                      else 'Leichten Betonstellriemen (25 cm hoch) für die Mauer erstellen, Beton gepumpt.' end,
          jsonb_build_object(pool_laenge::text, t_laenge::text, pool_vol::text, t_vol::text));
        stell_opts := stell_opts || neu;
      else
        perform pg_temp.kopiere_option(o.id, af_id, o.name, rf, o.beschreibung, '{}'::jsonb);
      end if;
    end loop;
    if rf <> array_length(plan.opts, 1) then raise exception 'Teilschritt %: erwartet % Optionen, kopiert %', plan.pool_ts, array_length(plan.opts, 1), rf; end if;
  end loop;

  -- Betonstellriemen: Meterzeit (Schalung) halbieren; die Betonierzeit halbiert sich über das Volumen
  update ressourcenzeile set menge_ausdruck = pg_temp.mul(menge_ausdruck, jsonb_build_object('lit', 0.5))
   where option_id = any(stell_opts) and artikel_id in (polier, garten) and menge_ausdruck::text like '%' || t_laenge::text || '%';
  get diagnostics n = row_count;
  if n < 2 then raise exception 'Schalungszeilen nicht gefunden (%)', n; end if;

  -- Randschiene (Zusatz bei der Folie) entfernen
  delete from ressourcenzeile where option_id in (select ao.id from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
    where s.offertentyp_id = ot and ao.name = 'Zusatz: Randschiene');
  delete from auswahloption where id in (select ao.id from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
    where s.offertentyp_id = ot and ao.name = 'Zusatz: Randschiene');

  -- Kontrolle: keine Verweise auf Werte anderer Offertentypen in den neuen Arbeitsschritten
  select count(*) into n from (
    select distinct (regexp_matches(rz.menge_ausdruck::text, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'g'))[1] as id
      from ressourcenzeile rz join auswahloption ao on ao.id = rz.option_id join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
     where s.offertentyp_id = ot and s.reihenfolge >= 7) chk
   where chk.id not in (select id::text from term where offertentyp_id = ot or offertentyp_id is null union select id::text from eingabefeld where offertentyp_id = ot);
  if n > 0 then raise exception 'Es gibt % Verweise auf Werte anderer Offertentypen', n; end if;
end $$;
