-- Gartenbeleuchtung: LED-Bänder als Tabelle (Stefan 2026-11-21).
-- Eine Zeile pro Band mit «Länge (m)». Pro Zeile rechnen versteckte Spalten:
--   Curveline EDGE 12x12 warmweiss (Staub): passendes Stück, Länge aufgerundet auf 0.5 m (0.5 … 10 m)
--   Netzgerät 24 VDC nach Leistung 12 W/m × Länge × 1.2 Reserve: ≤ 2.08 m 30 W, ≤ 3.47 m 50 W, ≤ 6.94 m 100 W, ≤ 13.88 m 200 W, darüber 300 W
--   U-Profil Aluminium 1 m: pro angefangenen Meter
-- Arbeit wie bisher: Polier + Gartenarbeiter je 0.5 Std./m, einmalig je 2.5 Std. (sobald ein Band erfasst ist).
-- Die alte Option «LED Band › Leuchtmittel» (pro m, ohne Band und Netzgerät) wird ersetzt; die 4 Offerten, die sie nutzen
-- (2026-010016, -010133, -010165, -010182), bekommen eine Tabellenzeile mit derselben Länge.
do $$
declare
  ot uuid := '5ce077fd-3ed6-4985-acb1-9a0fdc17a8c3';
  ts uuid; ef uuid; sl uuid; sp uuid; alt uuid; altfeld uuid; x numeric; nr text; art uuid; i int := 10; rf int := 1;
  L jsonb;
  ng record;
begin
  select t.id into ts from teilschritt t join arbeitsschritt a on a.id = t.arbeitsschritt_id where a.offertentyp_id = ot and t.name = 'LED Band';
  if exists (select 1 from eingabefeld where offertentyp_id = ot and name = 'LED-Bänder') then raise notice 'schon umgebaut'; return; end if;

  insert into eingabefeld (offertentyp_id, name, typ, reihenfolge, ist_tabelle, einheit) values (ot, 'LED-Bänder', 'zahl', 1, true, '') returning id into ef;
  insert into eingabefeld_tabelle_spalte (eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, formel_modus, ausgeblendet)
  values (ef, 'Länge', 'm', 1, false, 'baukasten', false) returning id into sl;
  L := jsonb_build_object('id', sl, 'ref', 'spalte');

  -- Netzgeräte
  for ng in select * from (values
      ('STAUBD_20.124030', 'Netzgerät 30 W', 0::numeric, 2.08::numeric),
      ('STAUBD_20.124040', 'Netzgerät 50 W', 2.08, 3.47),
      ('STAUBD_20.124100', 'Netzgerät 100 W', 3.47, 6.94),
      ('STAUBD_20.124200', 'Netzgerät 200 W', 6.94, 13.88),
      ('STAUBD_20.124300', 'Netzgerät 300 W', 13.88, 99999)) v(nr, name, von, bis) loop
    insert into eingabefeld_tabelle_spalte (eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausdruck, formel_baukasten_ausdruck, formel_modus, ausgeblendet)
    values (ef, ng.name, 'Stk.', i, true,
      jsonb_build_object('op', '*', 'args', jsonb_build_array(
        jsonb_build_object('op', '>', 'args', jsonb_build_array(L, jsonb_build_object('lit', ng.von))),
        jsonb_build_object('op', '<=', 'args', jsonb_build_array(L, jsonb_build_object('lit', ng.bis))))),
      null, 'baukasten', true) returning id into sp;
    i := i + 1;
    select id into art from artikel where artikelnummer_knecht = ng.nr;
    insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, menge_ausdruck, menge_formel_baukasten_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
    values (ts, 'material', art, jsonb_build_object('id', sp, 'ref', 'spalte'), jsonb_build_object('id', sp, 'ref', 'spalte'), 'baukasten', 1, 1, 1, 1, 100 + rf);
    rf := rf + 1;
  end loop;

  -- Curveline-Stücke 0.5 … 10 m
  for x in select generate_series(1, 20) * 0.5 loop
    select id, artikelnummer_knecht into art, nr from artikel
     where bezeichnung = 'Curveline EDGE 12x12, ' || trim(trailing '.' from trim(trailing '0' from x::text)) || ' m, warmweiss (2700 K)';
    if art is null then raise exception 'Curveline % m fehlt im Artikelstamm', x; end if;
    insert into eingabefeld_tabelle_spalte (eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausdruck, formel_modus, ausgeblendet)
    values (ef, 'Curveline ' || trim(trailing '.' from trim(trailing '0' from x::text)) || ' m', 'Stk.', i, true,
      jsonb_build_object('op', '=', 'args', jsonb_build_array(
        jsonb_build_object('op', '/', 'args', jsonb_build_array(
          jsonb_build_object('op', 'ceil', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(L, '{"lit": 2}'::jsonb)))),
          '{"lit": 2}'::jsonb)),
        jsonb_build_object('lit', x))),
      'baukasten', true) returning id into sp;
    i := i + 1;
    insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, menge_ausdruck, menge_formel_baukasten_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
    values (ts, 'material', art, jsonb_build_object('id', sp, 'ref', 'spalte'), jsonb_build_object('id', sp, 'ref', 'spalte'), 'baukasten', 1, 1, 1, 1, 10 + rf);
    rf := rf + 1;
  end loop;

  -- U-Profil pro angefangenen Meter
  insert into eingabefeld_tabelle_spalte (eingabefeld_id, name, einheit, reihenfolge, ist_berechnung, ausdruck, formel_modus, ausgeblendet)
  values (ef, 'U-Profil', 'Stk.', i, true, jsonb_build_object('op', 'ceil', 'args', jsonb_build_array(L)), 'baukasten', true) returning id into sp;
  insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, menge_ausdruck, menge_formel_baukasten_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
  select ts, 'material', id, jsonb_build_object('id', sp, 'ref', 'spalte'), jsonb_build_object('id', sp, 'ref', 'spalte'), 'baukasten', 1, 1, 1, 1, 200
  from artikel where artikelnummer_knecht = 'STAUBD_20.131093';

  -- Arbeit (wie bisher): je 0.5 Std./m + einmalig je 2.5 Std.
  insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, menge_ausdruck, menge_formel_baukasten_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
  select ts, 'personal', r.artikel_id, e.a, e.a, 'baukasten', 'LED-Band montieren: 0.5 Std./m + 2.5 Std. einmalig', 1, 1, 1, 1, r.rf
  from (select distinct on (artikel_id) artikel_id, case when artikel_id = '794454dd-c8a4-457a-ab66-b69fa4f6ea81' then 2 else 1 end rf
        from ressourcenzeile where option_id in (select o.id from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id where f.teilschritt_id = ts) and kategorie = 'personal') r,
       (select jsonb_build_object('op', '+', 'args', jsonb_build_array(
          jsonb_build_object('op', '*', 'args', jsonb_build_array(L, '{"lit": 0.5}'::jsonb)),
          jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('op', '>', 'args', jsonb_build_array(L, '{"lit": 0}'::jsonb)), '{"lit": 2.5}'::jsonb)))) a) e;

  update teilschritt set beschreibung = coalesce(nullif(beschreibung, ''), 'LED-Band inkl. Aluminiumprofil und Netzgerät liefern und montieren.') where id = ts;

  -- Offerten mit der alten Option: Tabellenzeile mit derselben Länge, alte Auswahl weg
  select o.id, f.id into alt, altfeld from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id where f.teilschritt_id = ts limit 1;
  insert into offerte_tabelle_zeile (id, offerte_id, eingabefeld_id, name, reihenfolge)
  select a.id, a.offerte_id, ef, 'LED-Band 1', 1 from offerte_auswahl a where a.option_id = alt;
  insert into offerte_tabelle_wert (zeile_id, spalte_id, wert) select a.id, sl, a.anzahl from offerte_auswahl a where a.option_id = alt;
  delete from offerte_auswahl where option_id = alt;
  delete from auswahloption where id = alt;
  delete from auswahlfeld where id = altfeld and not exists (select 1 from auswahloption where auswahlfeld_id = altfeld);
end $$;
