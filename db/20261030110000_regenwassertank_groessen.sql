-- Regenwassertank: alle Tankgroessen (Graf Platin Flachtank begehbar: 1500/3000/5000/7500/10000/15000 L), Nutzerwunsch 2026-10-30.
-- Aufbau: pro Tankgroesse eine Optionsgruppe "Tank X L" mit den Optionen "Baumaschinen L/M/S" (18 Optionen, ein Button je Tankgroesse mit Dropdown in Tool A).
-- Ersetzt die alte Einzeloption "5000 L Tank" (keine Offerte hing daran).
-- Mengen je Tank (T = Tankvolumen in m3):
--   Rundkies K = 0.6 x T (Hinterfuellung, wie bisher bei 5000 L: 3 m3)
--   Aushub locker Vl = (T + K) x 1.2 (Loch = Tank + Rundkies, Auflockerung 1.2 wie in den Flaechentabellen)
--   Deponie = Vl, Muldentransporte = Vl / 9 (min. 1), wie "Abtransport Mulde LKW" in Pool/Wassergarten
--   Personal (Polier + Gartenarbeiter je) = Vl x Satz Aushub + K x 0.5 Std. Hinterfuellung + 3 Std. Pumpe/Filter/Anschluesse
--   Maschinen (Bagger + Dumper je) = Vl x Satz Aushub; Saetze wie "Aushubarbeiten" in Pool/Wassergarten:
--     L: Personal 0.4, Maschine 0.25 / M: 0.6, 0.35 / S: 0.8, 0.45 (je m3 Aushub locker)
--   Kies-Transport per LKW (Sonderposition) nur ab K > 2 m3; bis 2 m3 faehrt der Lieferwagen (deckt die Lieferwagenfahrzeit-Karte ab).
--   Tankartikel nur fuer 5000 und 7500 L im Artikelstamm; fuer die anderen Groessen steht eine Freitext-Position "Preis eintragen".
do $$
declare
  ot uuid; af uuid; old_opt uuid; src_opt jsonb;
  j_pol jsonb; j_ga jsonb; j_hilf jsonb; j_dep jsonb; j_bag jsonb; j_dump jsonb; j_kt jsonb; j_kies jsonb; j_mulde jsonb; j_tank jsonb;
  t record; m record; opt uuid; gid uuid; vol numeric; k numeric; vl numeric; rr int; ord int := 0; a_tank uuid; txt text;
  n_opt int;
  pool constant uuid := '83bf9ae8-3095-4194-a9bb-4ea2dc08473e';
begin
  select ot_.id into ot from offertentyp ot_ where ot_.name = 'Regenwassertank';
  select a.id into af from auswahlfeld a join teilschritt ts on ts.id = a.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
   where ar.offertentyp_id = ot and ts.name = 'Regenwassertank';
  select ao.id into old_opt from auswahloption ao where ao.auswahlfeld_id = af and ao.name = '5000 L Tank';
  if af is null or old_opt is null then raise exception 'Regenwassertank / Option 5000 L Tank nicht gefunden (schon umgebaut?)'; end if;

  -- Quellzeilen aus der alten Option
  select to_jsonb(r) into j_pol  from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung like 'Polier / Vorarbeiter Wassergärten%';
  select to_jsonb(r) into j_ga   from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung = 'Gartenarbeiter';
  select to_jsonb(r) into j_hilf from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung = 'Pauschale Hilfsmaterial';
  select to_jsonb(r) into j_tank from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung like 'PLATIN Flachtank 5000 L%';
  select to_jsonb(r) into j_dep  from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung like 'Deponiegebühren Mat. getrennt%';
  select to_jsonb(r) into j_bag  from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung = 'Raupenbagger M';
  select to_jsonb(r) into j_dump from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung = 'Raupendumper M';
  select to_jsonb(r) into j_kt   from ressourcenzeile r join sonderposition_typ s on s.id = r.sonderposition_typ_id where r.option_id = old_opt and s.name = 'Kies-Transport';
  select to_jsonb(r) into j_kies from ressourcenzeile r join artikel a on a.id = r.artikel_id where r.option_id = old_opt and a.bezeichnung = 'Rundkies 16/32 mm';
  select to_jsonb(r) into j_mulde from ressourcenzeile r join auswahloption ao on ao.id = r.option_id join auswahlfeld f on f.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = f.teilschritt_id join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
    where ar.offertentyp_id = pool and ts.name = 'Aushub Abtransport' and ao.name = 'Abtransport Mulde LKW' and r.kategorie = 'logistik' limit 1;
  if j_pol is null or j_ga is null or j_hilf is null or j_tank is null or j_dep is null or j_bag is null or j_dump is null or j_kt is null or j_kies is null or j_mulde is null then
    raise exception 'Quellzeile fehlt';
  end if;
  select to_jsonb(ao) into src_opt from auswahloption ao where ao.id = old_opt;

  -- alte Option samt Zeilen entfernen
  delete from option_freitext_vorlage where option_id = old_opt;
  delete from ressourcenzeile where option_id = old_opt;
  delete from auswahloption where id = old_opt;

  for t in select * from (values (1500), (3000), (5000), (7500), (10000), (15000)) as v(liter) loop
    vol := t.liter / 1000.0;
    k := round(vol * 0.6, 2);
    vl := round((vol + k) * 1.2, 2);
    gid := gen_random_uuid();
    select id into a_tank from artikel where bezeichnung like 'PLATIN Flachtank ' || t.liter || ' L%' limit 1;

    for m in select * from (values ('L', 0.4, 0.25, 'Raupenbagger L', '(Raupen-) Dumper L'), ('M', 0.6, 0.35, 'Raupenbagger M', 'Raupendumper M'), ('S', 0.8, 0.45, 'Raupenbagger S', 'Raupendumper S')) as v(grp, rp, rm, bag, dump) loop
      ord := ord + 1;
      opt := gen_random_uuid();
      insert into auswahloption select * from jsonb_populate_record(null::auswahloption, src_opt || jsonb_build_object(
        'id', opt, 'name', 'Baumaschinen ' || m.grp, 'reihenfolge', ord, 'mehrfachauswahl', false,
        'optionsgruppe_id', gid, 'optionsgruppe_name', 'Tank ' || t.liter || ' L',
        'beschreibung', 'Regenwassertank ' || t.liter || ' Liter liefern und montieren. Inkl. Aushub und Entsorgung, Hinterfüllung mit Rundkies, Anschluss Pumpe und Filter.'));

      -- Personal: Aushub + Hinterfuellung (0.5 Std je m3 Kies) + 3 Std. Pumpe/Filter/Anschluesse
      txt := null;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_pol || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 1,
        'menge_ausdruck', jsonb_build_object('op', '+', 'args', jsonb_build_array(
          jsonb_build_object('op', '+', 'args', jsonb_build_array(
            jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', vl), jsonb_build_object('lit', m.rp))),
            jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', k), jsonb_build_object('lit', 0.5))))),
          jsonb_build_object('lit', 3)))));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_ga || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 2,
        'menge_ausdruck', jsonb_build_object('op', '+', 'args', jsonb_build_array(
          jsonb_build_object('op', '+', 'args', jsonb_build_array(
            jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', vl), jsonb_build_object('lit', m.rp))),
            jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', k), jsonb_build_object('lit', 0.5))))),
          jsonb_build_object('lit', 3)))));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_hilf || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 3));

      -- Tank: Artikel (5000/7500 L) oder Freitext-Platzhalter
      rr := 4;
      if a_tank is not null then
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_tank || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', rr, 'artikel_id', a_tank));
      else
        insert into option_freitext_vorlage (option_id, kategorie, bezeichnung, einheit, menge_vorschlag, preis_vorschlag, reihenfolge, ist_eigene_offertenposition)
          values (opt, 'material', 'PLATIN Flachtank ' || t.liter || ' L inkl. Transport + Domschacht (Artikel fehlt im Artikelstamm, Preis eintragen)', 'Stk.', 1, null, rr, false);
      end if;

      -- Aushub: Deponie, Mulden, Bagger, Dumper
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_dep || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 5,
        'menge_ausdruck', jsonb_build_object('lit', vl, '_einheit', 'm³')));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_mulde || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'teilschritt_id', null, 'reihenfolge', 6,
        'menge_ausdruck', jsonb_build_object('op', '/', 'args', jsonb_build_array(jsonb_build_object('lit', vl), jsonb_build_object('lit', 9)))));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_bag || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 7,
        'artikel_id', (select id from artikel where bezeichnung = m.bag limit 1),
        'menge_ausdruck', jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', vl), jsonb_build_object('lit', m.rm)))));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_dump || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 8,
        'artikel_id', (select id from artikel where bezeichnung = m.dump limit 1),
        'menge_ausdruck', jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('lit', vl), jsonb_build_object('lit', m.rm)))));

      -- Hinterfuellung: Kies-Transport per LKW nur ab 2 m3, sonst Lieferwagen (Lieferwagenfahrzeit-Karte)
      if k > 2 then
        insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_kt || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 9,
          'menge_ausdruck', jsonb_build_object('lit', k, '_einheit', 'm³')));
      end if;
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j_kies || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt, 'reihenfolge', 10,
        'menge_ausdruck', jsonb_build_object('lit', k, '_einheit', 'm³')));
    end loop;
  end loop;

  select count(*) into n_opt from auswahloption where auswahlfeld_id = af;
  if n_opt <> 18 then raise exception 'Erwartet 18 Optionen, erzeugt %', n_opt; end if;
end $$;
