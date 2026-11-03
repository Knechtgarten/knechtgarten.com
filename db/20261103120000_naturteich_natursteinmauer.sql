-- Naturteich/Schwimmteich > Mauern: Natursteinmauer wie in der Vorlage Mauern
-- (Natursteinmauer geschichtet in Blöcken + Natursteinmauer Plasselb wechselschichtig).
-- Die Mauern-Zeilen gelten je m² Sichtfläche, im Teich kommt die Länge der angehakten Umfangsstücke:
-- Menge = Wert der Mauern-Zeile x Mauerhöhe. Die leere Option «Natursteinmauer» entfällt, Kofra bleibt.
create or replace function pg_temp.mul(a jsonb, b jsonb) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, b)) $$;
create or replace function pg_temp.ref_t(i uuid) returns jsonb language sql as $$ select jsonb_build_object('id', i, 'ref', 'term') $$;

do $$
declare
  ot uuid; as_id uuid; h_ef uuid := '7c3b0f94-caa4-4be1-8273-77e0a69620c6'; hoehe jsonb;
  t_tonnen uuid := gen_random_uuid(); src_tonnen uuid := '20e2ffaa-a48b-45b5-8514-e0260ce7936e'; src_sicht uuid := 'd5e7a229-90df-4ca6-8820-8804c996d585';
  src_af uuid; new_ts uuid; new_af uuid; new_o uuid; r_ts record; r_o record; z record; neu jsonb; n int; reihe int;
  verweis jsonb := '[{"spalte_id": "laenge", "eingabefeld_id": "formen:tief"}]'::jsonb;
begin
  hoehe := jsonb_build_object('id', h_ef, 'ref', 'eingabefeld');
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select a.id into as_id from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Mauern';
  if ot is null or as_id is null then raise exception 'Naturteich/Mauern nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_id and name like 'Natursteinmauer%') then raise exception 'schon vorhanden'; end if;

  insert into term (id, offertentyp_id, name, typ, wert, einheit, reihenfolge, formel_modus)
    values (t_tonnen, ot, 'Tonnen pro m² Natursteinmauer', 'konstante', 1.2, 't/m²', 40, 'baukasten');

  select coalesce(max(reihenfolge), 0) into reihe from teilschritt where arbeitsschritt_id = as_id;

  for r_ts in select t.* from teilschritt t join arbeitsschritt a on a.id = t.arbeitsschritt_id join offertentyp m on m.id = a.offertentyp_id
              where m.name = 'Mauern' and a.name = 'Natursteinmauer' and t.name in ('Natursteinmauer geschichtet in Blöcken', 'Natursteinmauer Plasselb wechselschichtig') order by t.reihenfolge loop
    reihe := reihe + 1;
    new_ts := gen_random_uuid(); new_af := gen_random_uuid();
    insert into teilschritt select (jsonb_populate_record(null::teilschritt, to_jsonb(r_ts) || jsonb_build_object('id', new_ts, 'arbeitsschritt_id', as_id, 'reihenfolge', reihe, 'anzeige_eingabefeld_id', null, 'anzeige_term_id', null))).*;
    select f.id into src_af from auswahlfeld f where f.teilschritt_id = r_ts.id;
    insert into auswahlfeld select (jsonb_populate_record(null::auswahlfeld, to_jsonb(f) || jsonb_build_object('id', new_af, 'teilschritt_id', new_ts))).* from auswahlfeld f where f.id = src_af;

    for r_o in select * from auswahloption where auswahlfeld_id = src_af order by reihenfolge loop
      new_o := gen_random_uuid();
      insert into auswahloption select (jsonb_populate_record(null::auswahloption, to_jsonb(r_o) || jsonb_build_object('id', new_o, 'auswahlfeld_id', new_af, 'tabellenverweis', verweis,
        'auswahlgruppe_id', null, 'hinweistext', 'Beim Anklicken öffnet sich die Skizze: Umfangsstücke der Tiefenzone anhaken.'))).*;
      for z in select * from ressourcenzeile where option_id = r_o.id order by reihenfolge loop
        if z.menge_ausdruck ? 'lit' then
          neu := pg_temp.mul(z.menge_ausdruck, hoehe);
        elsif z.menge_ausdruck = jsonb_build_object('id', src_tonnen, 'ref', 'term') then
          neu := pg_temp.mul(pg_temp.ref_t(t_tonnen), hoehe);
        elsif z.menge_ausdruck->>'op' = '*' and z.menge_ausdruck->'args'->0 = jsonb_build_object('id', src_sicht, 'ref', 'term') then
          neu := pg_temp.mul(z.menge_ausdruck->'args'->1, hoehe);   -- Sichtfläche x 0.1 Std. -> je m Länge: 0.1 Std. x Höhe
        else
          raise exception 'Unbekannte Menge in % / %: %', r_o.name, z.reihenfolge, z.menge_ausdruck;
        end if;
        insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(z) || jsonb_build_object('id', gen_random_uuid(), 'option_id', new_o,
          'menge_ausdruck', neu, 'teilschritt_id', case when z.teilschritt_id is null then null else new_ts end))).*;
      end loop;
    end loop;
  end loop;

  -- leere Option «Natursteinmauer» entfernen (Kofra bleibt); zwei Test-Offerten vom 31.10. hatten sie angehakt, diese Auswahl entfällt mit
  delete from offerte_auswahl where option_id = '85098d93-a59b-41f5-8206-1b9ccf168ced';
  delete from offerte_arbeitsschritt_option where option_id = '85098d93-a59b-41f5-8206-1b9ccf168ced';
  delete from offerte_teilschritt_option where option_id = '85098d93-a59b-41f5-8206-1b9ccf168ced';
  delete from auswahloption where id = '85098d93-a59b-41f5-8206-1b9ccf168ced';
  get diagnostics n = row_count; if n <> 1 then raise exception 'alte Option nicht gefunden'; end if;
end $$;
