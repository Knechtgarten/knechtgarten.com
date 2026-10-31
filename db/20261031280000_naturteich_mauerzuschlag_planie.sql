-- Naturteich/Schwimmteich: (1) Mauerzuschlag fest in der Tiefenzone (Platte und Aushub rechnen mit Fläche + Umfang x Zuschlag-Breite),
-- (2) Feinplanie von Hand pro m2 Teichfläche (0.3 Std. je Person, ca. 1 Tag bei 30 m2) in den Baumaschinen-Optionen.
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;
create or replace function pg_temp.ref_e(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'eingabefeld') $$;
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.add(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '+', 'args', jsonb_build_array(a, b)) $$;

do $$
declare
  ot uuid; s_ft uuid; s_ff uuid; s_uf uuid; e_wt uuid; k_aufbau uuid; k_dicke uuid; k_mauer uuid := gen_random_uuid(); k_planie uuid := gen_random_uuid(); f_platte uuid := gen_random_uuid();
  polier uuid; garten uuid; o record; jz jsonb; mx int; n int;
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select id into s_ft from term where offertentyp_id = ot and systemwert_key = 'form_flaeche_teich';
  select id into s_ff from term where offertentyp_id = ot and systemwert_key = 'form_flaeche_tief';
  select id into s_uf from term where offertentyp_id = ot and systemwert_key = 'form_umfang_tief';
  select id into e_wt from eingabefeld where offertentyp_id = ot and name = 'Wassertiefe';
  select id into k_aufbau from term where offertentyp_id = ot and name = 'Aufbau Boden Tiefenzone';
  select id into k_dicke from term where offertentyp_id = ot and name = 'Dicke Betonplatte';
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  if ot is null or s_ft is null or s_ff is null or s_uf is null or e_wt is null or k_aufbau is null or k_dicke is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from term where offertentyp_id = ot and name = 'Plattenfläche Tiefenzone') then raise exception 'Schon umgestellt'; end if;

  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus) values
    (k_mauer, ot, 'Mauerzuschlag Breite', 'konstante', 0.5, 'm', 20, 'baukasten'),
    (k_planie, ot, 'Feinplanie von Hand', 'konstante', 0.3, 'Std./m²', 21, 'baukasten');
  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus) values
    (f_platte, ot, 'Plattenfläche Tiefenzone', 'formel', pg_temp.add(pg_temp.ref_t(s_ff), pg_temp.mul(pg_temp.ref_t(s_uf), pg_temp.ref_t(k_mauer))), 'm²', 22, 'baukasten');

  update term set ausdruck = pg_temp.mul(pg_temp.ref_t(f_platte), pg_temp.add(pg_temp.ref_e(e_wt), pg_temp.ref_t(k_aufbau))) where offertentyp_id = ot and name = 'Aushub Tiefenzone (fest)';
  update term set ausdruck = pg_temp.mul(pg_temp.ref_t(f_platte), pg_temp.ref_t(k_dicke)) where offertentyp_id = ot and name = 'Beton Platte Tiefenzone';

  -- Betonplatte (Kopie Pool): überall wo bisher die Fläche der Tiefenzone stand, jetzt die Plattenfläche inkl. Mauerzuschlag
  update ressourcenzeile rz set menge_ausdruck = replace(rz.menge_ausdruck::text, s_ff::text, f_platte::text)::jsonb
    from auswahloption ao, auswahlfeld af, teilschritt ts, arbeitsschritt s
   where ao.id = rz.option_id and af.id = ao.auswahlfeld_id and ts.id = af.teilschritt_id and s.id = ts.arbeitsschritt_id
     and s.offertentyp_id = ot and s.name = 'Betonplatte Tiefenzone' and rz.menge_ausdruck::text like '%' || s_ff::text || '%';
  get diagnostics n = row_count;
  if n < 1 then raise exception 'Keine Zeile der Betonplatte umgestellt'; end if;

  -- Feinplanie in den Baumaschinen-Optionen: zwei Zeilen (Polier, Gartenarbeiter) je Teichfläche x 0.3 Std.
  for o in select ao.id from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id
            where s.offertentyp_id = ot and s.name = 'Aushub' and ao.name like 'Baumaschinen %' loop
    select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = o.id and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;
    select max(reihenfolge) into mx from ressourcenzeile where option_id = o.id;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', mx + 1, 'artikel_id', polier,
      'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(s_ft), pg_temp.ref_t(k_planie)), 'notiz', 'Feinplanie von Hand: Teichfläche x 0.3 Std.'));
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', mx + 2, 'artikel_id', garten,
      'menge_ausdruck', pg_temp.mul(pg_temp.ref_t(s_ft), pg_temp.ref_t(k_planie)), 'notiz', 'Feinplanie von Hand: Teichfläche x 0.3 Std.'));
  end loop;
end $$;
