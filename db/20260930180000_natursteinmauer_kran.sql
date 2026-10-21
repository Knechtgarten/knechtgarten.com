-- ============================================================================
-- Natursteinmauer: Kran-Optionen (Kran -20m / -30m / -45m) im selben Feld wie
-- "von Hand" / "Maschine S/M/L". Gleiche Zeilen wie "von Hand" (Personal 4.5 Std/t,
-- Stein, Transport gekippt) plus Kranwagen: 0.3 Std je Tonne (gleicher Ansatz wie beim Kranaushub).
-- ============================================================================
do $$
declare
  ot uuid; af uuid; o_hand uuid; tmpl jsonb; j jsonb; rec record; oid uuid; rr int; t_gew uuid; src uuid; kranrow uuid; n int;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select o.id, o.auswahlfeld_id into o_hand, af from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = ot and a.name = 'Natursteinmauer' and o.name = 'von Hand';
  select id into t_gew from term where offertentyp_id = ot and name = 'Gewicht Natursteinmauer';
  if o_hand is null or t_gew is null then raise exception 'Natursteinmauer nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af and name = 'Kran -20m') then raise exception 'Kran gibt es schon'; end if;
  select max(reihenfolge) into rr from auswahloption where auswahlfeld_id = af;

  select to_jsonb(o) into tmpl from auswahloption o where o.id = o_hand;
  for rec in select * from (values
      ('Kran -20m', 'Kranaushub -20m', 'Kranwagen 3-Achs Sattel (20m/1,1To)', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Kranwagen (bis 20 m) setzen.'),
      ('Kran -30m', 'Kranaushub -30m', 'Kranwagen 5-Achs Spezial (31m/1,1To)', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Kranwagen (bis 30 m) setzen.'),
      ('Kran -45m', 'Kranaushub -45m', 'Pneukran MK 88', 'Natursteinmauer aus Plasselb-Blöcken im Wechselschichtverband mit Pneukran (bis 45 m) setzen.')
    ) as v(name, quelle, art, beschr) loop
    rr := rr + 1; oid := gen_random_uuid();
    insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'name', rec.name, 'reihenfolge', rr, 'beschreibung', rec.beschr));
    -- Zeilen von "von Hand" kopieren (gleiche Formeln)
    insert into ressourcenzeile select * from jsonb_populate_recordset(null::ressourcenzeile,
      (select jsonb_agg(to_jsonb(rz) || jsonb_build_object('id', gen_random_uuid(), 'option_id', oid)) from ressourcenzeile rz where rz.option_id = o_hand));
    select count(*) into n from ressourcenzeile where option_id = oid;
    -- Kranwagen-Zeile von der passenden Kranaushub-Option kopieren
    select rz.id into src from ressourcenzeile rz join artikel a on a.id = rz.artikel_id join auswahloption qo on qo.id = rz.option_id join auswahlfeld qf on qf.id = qo.auswahlfeld_id join teilschritt qts on qts.id = qf.teilschritt_id join arbeitsschritt qa on qa.id = qts.arbeitsschritt_id
     where qa.offertentyp_id = ot and qo.name = rec.quelle and a.bezeichnung = rec.art limit 1;
    if src is null then raise exception 'Kran-Zeile % nicht gefunden', rec.art; end if;
    select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = src;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j || jsonb_build_object('id', gen_random_uuid(), 'option_id', oid, 'teilschritt_id', null,
        'reihenfolge', n + 1, 'menge_ausdruck', jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('id', t_gew, 'ref', 'term'), jsonb_build_object('lit', 0.3))),
        'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null, 'verschnitt_prozent', null, 'mindestmenge', null, 'mengenoption_ausgenommen', false));
  end loop;
  raise notice 'Kran-Optionen angelegt.';
end $$;
