-- Naturteich/Schwimmteich: Arbeitsschritt "Plattenbelag Tiefenzone" (nach der Betonplatte), Kopie der Pool-Option "Boden auf Beton/Folie m2":
--  Keramikplatte NOBLESSE FOREVER grey (20 % Verschnitt) = Fläche Tiefenzone; Personal je Person:
--  0.75 Std. je m2 Boden, 0.5 Std. je m Schnittlänge, 0.5 Std. je m Umfang.
--  Schnittlänge Tiefenzone = Umfang Tiefenzone / 2 (beim Rechteck eine Länge plus eine Breite, wie im Pool).
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;

do $$
declare
  ot uuid; pool_ot uuid; s_ff uuid; s_uf uuid; t_schnitt uuid := gen_random_uuid(); as_id uuid := gen_random_uuid(); ts_id uuid := gen_random_uuid(); af_id uuid := gen_random_uuid();
  as_tpl jsonb; ts_tpl jsonb; af_tpl jsonb; src uuid; neu uuid := gen_random_uuid(); j jsonb; jr jsonb; r record; n int;
begin
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select id into pool_ot from offertentyp where name = 'Pooloptionen' and papierkorb_am is null;
  select id into s_ff from term where offertentyp_id = ot and systemwert_key = 'form_flaeche_tief';
  select id into s_uf from term where offertentyp_id = ot and systemwert_key = 'form_umfang_tief';
  select to_jsonb(s) into as_tpl from arbeitsschritt s where s.offertentyp_id = ot and s.name = 'Betonplatte Tiefenzone';
  select to_jsonb(t), to_jsonb(f) into ts_tpl, af_tpl from teilschritt t join arbeitsschritt s on s.id = t.arbeitsschritt_id join auswahlfeld f on f.teilschritt_id = t.id where s.offertentyp_id = ot and s.name = 'Betonplatte Tiefenzone';
  select ao.id into src from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = pool_ot and s.name = 'Plattenbelag Poolboden' and ao.name = 'Boden auf Beton/Folie m2';
  if ot is null or s_ff is null or s_uf is null or as_tpl is null or src is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Plattenbelag Tiefenzone') then raise exception 'Schon vorhanden'; end if;

  insert into term (id, offertentyp_id, name, typ, ausdruck, einheit, reihenfolge, formel_modus)
    values (t_schnitt, ot, 'Schnittlänge Tiefenzone', 'formel', pg_temp.mul(pg_temp.ref_t(s_uf), jsonb_build_object('lit', 0.5)), 'm', 23, 'baukasten');

  -- Reihenfolge: Plattenbelag auf Position 4, Folie und Vlies 5, Mauern 6
  update arbeitsschritt set reihenfolge = reihenfolge + 1 where offertentyp_id = ot and reihenfolge >= 4;
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt, as_tpl || jsonb_build_object('id', as_id, 'name', 'Plattenbelag Tiefenzone', 'reihenfolge', 4));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, ts_tpl || jsonb_build_object('id', ts_id, 'arbeitsschritt_id', as_id, 'name', 'Plattenbelag', 'reihenfolge', 1));
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, af_tpl || jsonb_build_object('id', af_id, 'teilschritt_id', ts_id, 'name', 'Plattenbelag', 'reihenfolge', 1));

  select to_jsonb(o) into j from auswahloption o where o.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', neu, 'auswahlfeld_id', af_id, 'name', 'Keramikplatte auf Betonplatte', 'reihenfolge', 1,
      'beschreibung', 'Boden der Tiefenzone mit Keramikplatten belegen.', 'hinweistext', 'Fläche = Fläche Tiefenzone. Verschnitt 20 %.',
      'mehrfachauswahl', false, 'mengenoption', false, 'tabellenverweis', null, 'optionsgruppe_id', null, 'optionsgruppe_name', null, 'auswahlgruppe_id', null));
  for r in select * from ressourcenzeile where option_id = src order by reihenfolge loop
    jr := to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu);
    jr := jsonb_set(jr, '{menge_ausdruck}', replace(replace(replace((jr->'menge_ausdruck')::text,
      'd981115b-2905-4e11-9e4a-2cf74bc2389d', s_ff::text), '14422c2f-9a10-41b0-9ecc-b59a8aa597aa', t_schnitt::text), 'ff746885-2246-42c6-b348-b8c523c0b5a1', s_uf::text)::jsonb);
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jr);
  end loop;

  -- Kontrolle: keine Verweise auf Werte anderer Offertentypen
  select count(*) into n from (
    select distinct (regexp_matches(rz.menge_ausdruck::text, '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', 'g'))[1] as id
      from ressourcenzeile rz where rz.option_id = neu) chk
   where chk.id not in (select id::text from term where offertentyp_id = ot or offertentyp_id is null union select id::text from eingabefeld where offertentyp_id = ot);
  if n > 0 then raise exception 'Es gibt % Verweise auf Werte anderer Offertentypen', n; end if;
end $$;
