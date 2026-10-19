-- ============================================================================
-- Beläge, Hartflächen: Fundation in zwei Teilschritte aufteilen, jeweils mit
-- Auswahl der Baumaschinen bzw. Kräne (wie beim Aushub).
--
--  Teilschritt "Fundation Kieseinbau LKW":   Baumaschinen L / M / S,
--                                            Kran -20m / -30m / -45m
--  Teilschritt "Fundation Kieseinbau Lieferwagen": Baumaschinen S
--
-- Bestehende Optionen bleiben (und damit offene Offerten):
--   "Fundation Kieseinbau LKW"        -> "Baumaschinen M"  (Zeilen unveraendert)
--   "Fundation Kieseinbau Lieferwagen" -> "Baumaschinen S" im neuen Teilschritt
--
-- Zeiten (Kieseinbau ist weniger maschinenintensiv als Aushub), proportional
-- zum Aushub, ausgehend von den bestehenden M-Werten (Personal 0.35, Maschinen 0.25):
--   Personal:  L 0.23 | M 0.35 | S 0.47     (Aushub 0.4 | 0.6 | 0.8)
--   Maschinen: L 0.18 | M 0.25 | S 0.32     (Aushub 0.25 | 0.35 | 0.45)
--   Kran: Personal 0.18, Kran 0.21, kein Bagger/Dumper
-- ============================================================================
do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d';
  as_fund uuid; ts_lkw uuid; af_lkw uuid; opt_m uuid; opt_lw uuid;
  ts_lw uuid := gen_random_uuid(); af_lw uuid := gen_random_uuid();
  j jsonb; neu uuid; r int;
  art_dump_l uuid; art_bag_l uuid; art_dump_s uuid; art_bag_s uuid; art_dump_m uuid; art_bag_m uuid;
  kranname text; kran_row record; kran_opt uuid; fund_term jsonb;
  p_l constant numeric := 0.23; p_s constant numeric := 0.47; m_l constant numeric := 0.18; m_s constant numeric := 0.32;
  p_kran constant numeric := 0.18; k_kran constant numeric := 0.21;
  n int;
begin
  select a.id into as_fund from arbeitsschritt a where a.offertentyp_id = ot and a.name = 'Fundation';
  select ts.id into ts_lkw from teilschritt ts where ts.arbeitsschritt_id = as_fund and ts.name = 'Fundation';
  select af.id into af_lkw from auswahlfeld af where af.teilschritt_id = ts_lkw;
  select o.id into opt_m  from auswahloption o where o.auswahlfeld_id = af_lkw and o.name = 'Fundation Kieseinbau LKW';
  select o.id into opt_lw from auswahloption o where o.auswahlfeld_id = af_lkw and o.name = 'Fundation Kieseinbau Lieferwagen';
  if as_fund is null or ts_lkw is null or af_lkw is null or opt_m is null or opt_lw is null then
    raise exception 'Fundation-Struktur nicht wie erwartet gefunden - nichts geaendert.';
  end if;

  -- Maschinen-Artikel aus dem Aushub (gleiche Artikel wie dort)
  select rz.artikel_id into art_dump_l from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join artikel ar on ar.id = rz.artikel_id
   where o.name = 'Baumaschinen L' and rz.kategorie = 'maschine' and ar.bezeichnung ilike '%dumper%' and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);
  select rz.artikel_id into art_bag_l from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join artikel ar on ar.id = rz.artikel_id
   where o.name = 'Baumaschinen L' and rz.kategorie = 'maschine' and ar.bezeichnung ilike '%bagger%' and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);
  select rz.artikel_id into art_dump_s from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join artikel ar on ar.id = rz.artikel_id
   where o.name = 'Baumaschinen S' and rz.kategorie = 'maschine' and ar.bezeichnung ilike '%dumper%' and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);
  select rz.artikel_id into art_bag_s from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join artikel ar on ar.id = rz.artikel_id
   where o.name = 'Baumaschinen S' and rz.kategorie = 'maschine' and ar.bezeichnung ilike '%bagger%' and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);
  if art_dump_l is null or art_bag_l is null or art_dump_s is null or art_bag_s is null then
    raise exception 'Maschinen-Artikel L/S im Aushub nicht gefunden - nichts geaendert.';
  end if;

  -- Vorlage-Zeilen der bestehenden LKW-Option (M) als Muster merken
  create temp table _muster on commit drop as select rz.* from ressourcenzeile rz where rz.option_id = opt_m;
  select (menge_ausdruck->'args'->0) into fund_term from _muster where kategorie = 'personal' limit 1;

  -- 1. Teilschritt umbenennen, zweiten Teilschritt (Lieferwagen) mit eigenem Auswahlfeld anlegen
  update teilschritt set name = 'Fundation Kieseinbau LKW' where id = ts_lkw;
  update auswahlfeld set name = 'Fundation Kieseinbau LKW' where id = af_lkw;
  select to_jsonb(ts) into j from teilschritt ts where ts.id = ts_lkw;
  j := j || jsonb_build_object('id', ts_lw, 'name', 'Fundation Kieseinbau Lieferwagen', 'reihenfolge', (select coalesce(max(reihenfolge),0)+1 from teilschritt where arbeitsschritt_id = as_fund));
  insert into teilschritt select * from jsonb_populate_record(null::teilschritt, j);
  select to_jsonb(af) into j from auswahlfeld af where af.id = af_lkw;
  j := j || jsonb_build_object('id', af_lw, 'teilschritt_id', ts_lw, 'name', 'Fundation Kieseinbau Lieferwagen');
  insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, j);

  -- 2. Lieferwagen-Option in den neuen Teilschritt verschieben, Baumaschinen S
  update auswahloption set auswahlfeld_id = af_lw, name = 'Baumaschinen S', reihenfolge = 1 where id = opt_lw;
  update ressourcenzeile set artikel_id = art_dump_s,
         menge_ausdruck = jsonb_build_object('op','*','args', jsonb_build_array(menge_ausdruck->'args'->0, jsonb_build_object('lit', m_s)))
   where option_id = opt_lw and kategorie = 'maschine' and artikel_id in (select id from artikel where bezeichnung ilike '%dumper%');
  update ressourcenzeile set artikel_id = art_bag_s,
         menge_ausdruck = jsonb_build_object('op','*','args', jsonb_build_array(menge_ausdruck->'args'->0, jsonb_build_object('lit', m_s)))
   where option_id = opt_lw and kategorie = 'maschine' and artikel_id in (select id from artikel where bezeichnung ilike '%bagger%');
  update ressourcenzeile set menge_ausdruck = jsonb_build_object('op','*','args', jsonb_build_array(menge_ausdruck->'args'->0, jsonb_build_object('lit', p_s)))
   where option_id = opt_lw and kategorie = 'personal' and menge_ausdruck->>'op' = '*' and (menge_ausdruck->'args'->1->>'lit')::numeric = 0.35;

  -- 3. LKW-Teilschritt: bestehende Option wird "Baumaschinen M" (Zeilen bleiben)
  update auswahloption set name = 'Baumaschinen M', reihenfolge = 2 where id = opt_m;

  -- 4. Neue Optionen L und S (Kopie der M-Option, Maschinen/Zeiten angepasst)
  for r in 1..2 loop
    declare
      nm text := case r when 1 then 'Baumaschinen L' else 'Baumaschinen S' end;
      rf int := case r when 1 then 1 else 3 end;
      fp numeric := case r when 1 then p_l else p_s end;
      fm numeric := case r when 1 then m_l else m_s end;
      ad uuid := case r when 1 then art_dump_l else art_dump_s end;
      ab uuid := case r when 1 then art_bag_l else art_bag_s end;
      rec record;
    begin
      select to_jsonb(o) into j from auswahloption o where o.id = opt_m;
      neu := gen_random_uuid();
      j := j || jsonb_build_object('id', neu, 'name', nm, 'reihenfolge', rf);
      insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);
      for rec in select * from _muster order by reihenfolge loop
        j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu);
        if rec.kategorie = 'personal' and rec.menge_ausdruck->>'op' = '*' then
          j := j || jsonb_build_object('menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(rec.menge_ausdruck->'args'->0, jsonb_build_object('lit', fp))));
        elsif rec.kategorie = 'maschine' and rec.artikel_id in (select id from artikel where bezeichnung ilike '%dumper%') then
          j := j || jsonb_build_object('artikel_id', ad, 'menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(rec.menge_ausdruck->'args'->0, jsonb_build_object('lit', fm))));
        elsif rec.kategorie = 'maschine' and rec.artikel_id in (select id from artikel where bezeichnung ilike '%bagger%') then
          j := j || jsonb_build_object('artikel_id', ab, 'menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(rec.menge_ausdruck->'args'->0, jsonb_build_object('lit', fm))));
        end if;
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
      end loop;
    end;
  end loop;

  -- 5. Kran-Optionen: Personal, Kran (statt Bagger/Dumper), Kies-Transport, Kies, Kleingeraete
  n := 4;
  for kranname in select unnest(array['Kranaushub -20m','Kranaushub -30m','Kranaushub -45m']) loop
    select rz.* into kran_row from ressourcenzeile rz join auswahloption o on o.id = rz.option_id
     where o.name = kranname and rz.kategorie = 'logistik'
       and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = ot);
    if kran_row.id is null then raise exception 'Kran-Zeile fuer % nicht gefunden - nichts geaendert.', kranname; end if;
    select to_jsonb(o) into j from auswahloption o where o.id = opt_m;
    kran_opt := gen_random_uuid();
    j := j || jsonb_build_object('id', kran_opt, 'name', replace(kranname, 'Kranaushub', 'Kran Kieseinbau'), 'reihenfolge', n);
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, j);
    declare rec record; rr int := 0; begin
      for rec in select * from _muster where kategorie in ('personal') order by reihenfolge loop
        rr := rr + 1;
        j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', kran_opt, 'reihenfolge', rr,
              'menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(rec.menge_ausdruck->'args'->0, jsonb_build_object('lit', p_kran))));
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
      end loop;
      -- Kran (aus dem Aushub kopiert, Menge mit Volumen Fundation)
      rr := rr + 1;
      j := to_jsonb(kran_row) || jsonb_build_object('id', gen_random_uuid(), 'option_id', kran_opt, 'reihenfolge', rr,
            'menge_ausdruck', jsonb_build_object('op','*','args', jsonb_build_array(fund_term, jsonb_build_object('lit', k_kran))));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
      for rec in select * from _muster where kategorie not in ('personal') and not (kategorie = 'maschine' and (artikel_id in (select id from artikel where bezeichnung ilike '%dumper%' or bezeichnung ilike '%bagger%'))) order by reihenfolge loop
        rr := rr + 1;
        j := to_jsonb(rec) || jsonb_build_object('id', gen_random_uuid(), 'option_id', kran_opt, 'reihenfolge', rr);
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
      end loop;
    end;
    n := n + 1;
  end loop;

  raise notice 'Fundation aufgeteilt: LKW-Teilschritt % mit 6 Optionen, Lieferwagen-Teilschritt % mit 1 Option.', ts_lkw, ts_lw;
end $$;
