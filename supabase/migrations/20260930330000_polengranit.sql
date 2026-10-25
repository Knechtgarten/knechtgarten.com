-- Natursteinmauer: Polengranit-Quader (Fontarocca) in zwei Teilschritten
--  "Polengranit Grossmengen (komplett Lkw)": Preis franko (231 / 222 / 222 CHF/t EK), kein Transport
--  "Polengranit Kleinmengen (ab Lager)":    Preis ab Lager Liestal (257 / 248 / 248 CHF/t EK) + Fontarocca-Transport je Tonne
--  Buttons: 30er Maschine M, 30er Maschine L, 40er Maschine L, 50er Maschine L
--  Gewicht je m² Sichtfläche: 30er 1.0 t, 40er 1.15 t, 50er 1.3 t. Arbeitszeit wie Plasselb-Schichten.
--  VK = EK x 1.05 (Fontarocca-Regel), Einheit t, Zuordnung je Mauerzeile (Gruppe "mauer").
do $$
declare
  ot uuid; as_nat uuid; fo uuid; ts_src uuid; af_src uuid; o_m uuid; o_l uuid; a_stein_alt uuid; a_tr uuid; tmpl jsonb; rec record; oid uuid; rr int; src uuid; gruppe int; n int;
  ts_neu uuid; af_neu uuid; a_neu uuid; o_src uuid; j jsonb; tab_verweis jsonb; r record;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_nat from arbeitsschritt where offertentyp_id = ot and name = 'Natursteinmauer';
  select id into fo from lieferant where name = 'Fontarocca AG';
  select t.id, f.id into ts_src, af_src from teilschritt t join auswahlfeld f on f.teilschritt_id = t.id where t.arbeitsschritt_id = as_nat and t.name = 'Natursteinmauer geschichtet in Blöcken';
  select id into o_m from auswahloption where auswahlfeld_id = af_src and name = 'Plasselb Maschine M';
  select id into o_l from auswahloption where auswahlfeld_id = af_src and name = 'Plasselb Maschine L';
  select id into a_stein_alt from artikel where bezeichnung = 'Plasselb Natursteinblöcke 300-500 L (Schichten)';
  select id into a_tr from artikel where bezeichnung = 'Transport Natursteinplatten' and lieferant_id = fo;
  if fo is null or ts_src is null or o_m is null or o_l is null or a_stein_alt is null or a_tr is null then raise exception 'Grundlage nicht gefunden'; end if;
  if exists (select 1 from teilschritt where arbeitsschritt_id = as_nat and name like 'Polengranit%') then raise exception 'Polengranit gibt es schon'; end if;
  select tabellenverweis into tab_verweis from auswahloption where id = o_m;

  for gruppe in 1..2 loop   -- 1 = Grossmengen (franko), 2 = Kleinmengen (ab Lager)
    ts_neu := gen_random_uuid(); af_neu := gen_random_uuid();
    select to_jsonb(t) into tmpl from teilschritt t where t.id = ts_src;
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt, tmpl || jsonb_build_object('id', ts_neu, 'name', case gruppe when 1 then 'Polengranit Grossmengen (komplett Lkw)' else 'Polengranit Kleinmengen (ab Lager)' end, 'reihenfolge', 3 + gruppe, 'beschreibung', null));
    select to_jsonb(f) into tmpl from auswahlfeld f where f.id = af_src;
    insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld, tmpl || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', case gruppe when 1 then 'Polengranit Grossmengen (komplett Lkw)' else 'Polengranit Kleinmengen (ab Lager)' end));
    rr := 0;
    for rec in select * from (values
        ('30er Maschine M', '30x30-35 cm', 'OS.220.330', 1.0,  231, 257, o_m, 'M'),
        ('30er Maschine L', '30x30-35 cm', 'OS.220.330', 1.0,  231, 257, o_l, 'L'),
        ('40er Maschine L', '40x40-45 cm', 'OS.220.340', 1.15, 222, 248, o_l, 'L'),
        ('50er Maschine L', '50x50-55 cm', 'OS.220.350', 1.3,  222, 248, o_l, 'L')
      ) as v(name, mass, pnr, tm2, ep_franko, ep_lager, quelle, gr) loop
      -- Artikel je Grösse und Preisklasse einmal anlegen
      select id into a_neu from artikel where lieferant_id = fo and artikelnummer_knecht = 'FONTAR_POLEN_' || rec.pnr || case gruppe when 1 then '_LKW' else '_LAGER' end;
      if a_neu is null then
        a_neu := gen_random_uuid();
        insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
        values (a_neu, fo, 'material', 'FONTAR_POLEN_' || rec.pnr || case gruppe when 1 then '_LKW' else '_LAGER' end, rec.pnr || case gruppe when 1 then '-LKW' else '-LAGER' end,
                'Polengranit Quader ' || rec.mass || ' allseits gespalten (' || case gruppe when 1 then 'komplett Lkw franko' else 'ab Lager Liestal' end || ')', 't',
                case gruppe when 1 then rec.ep_franko else rec.ep_lager end, round((case gruppe when 1 then rec.ep_franko else rec.ep_lager end) * 1.05), 'CHF', 1, 8.1,
                'Gewicht ca. ' || rec.tm2 || ' t/m² Sichtfläche, Länge ca. 60-140 cm, Fontarocca Preisliste Liestal', false, false, false, true, false);
      end if;
      rr := rr + 1; oid := gen_random_uuid();
      select to_jsonb(o) into tmpl from auswahloption o where o.id = rec.quelle;
      insert into auswahloption select * from jsonb_populate_record(null::auswahloption, tmpl || jsonb_build_object('id', oid, 'auswahlfeld_id', af_neu, 'name', rec.name, 'reihenfolge', rr,
          'beschreibung', 'Natursteinmauer aus Polengranit-Quadern ' || rec.mass || ' in Schichten setzen, Maschine ' || rec.gr || '.'));
      -- Zeilen der Plasselb-Option kopieren: Stein-Artikel tauschen, Menge = Gewicht je m²
      for r in select * from ressourcenzeile where option_id = rec.quelle order by reihenfolge loop
        j := to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', oid);
        if r.artikel_id = a_stein_alt then
          j := j || jsonb_build_object('artikel_id', a_neu, 'menge_ausdruck', jsonb_build_object('lit', rec.tm2), 'menge_formel_modus', 'baukasten');
        end if;
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j);
        if r.artikel_id = a_stein_alt and gruppe = 2 then   -- Fontarocca-Lieferung je Tonne
          insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
            to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', oid, 'artikel_id', a_tr, 'kategorie', 'logistik', 'reihenfolge', 9,
              'menge_ausdruck', jsonb_build_object('lit', rec.tm2), 'menge_formel_modus', 'baukasten', 'verschnitt_prozent', null, 'mindestmenge', null));
        end if;
      end loop;
    end loop;
  end loop;
  select count(*) into n from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_nat and t.name like 'Polengranit%';
  if n <> 8 then raise exception 'Erwartet 8 Optionen, angelegt %', n; end if;
end $$;
