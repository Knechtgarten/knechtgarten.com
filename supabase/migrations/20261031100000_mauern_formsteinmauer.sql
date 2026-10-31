-- Mauern: neuer Arbeitsschritt "Formsteinmauer" (nach "Verblender"): gesägte Formsteine (Fontarocca), Stein auf Stein verklebt.
-- Je Stein ein Teilschritt, je Steinhöhe eine Option (Preis je m² bzw. je t). Mengen je m² Mauerfläche (Tabelle "Mauer").
--  Steine (gelb markiert in der Fontarocca-Preisliste): Maggia Granit Systemmauerwerk, Ibero Macado, Piasentina Calcit Sediment, Jurakalkstein Antico.
--  VK = EK x 1.05 (Fontarocca-Regel). Transport Fontarocca je Tonne (ab Lager Liestal), Gewicht je m² laut Preisliste.
--  Arbeit: 5 m² pro Tag = 9 Std. / 5 = 1.8 Std. je m² für Polier und Gartenarbeiter.
--  Kleber SAKRET Euroflex EF 25 kg (Preis fehlt noch im Artikelstamm). Menge Schätzung: Lagerfugenfläche = Tiefe / Höhe je m² Ansicht,
--  3 kg Kleber je m² Lagerfuge + 10 % für Stossfugen.
--  Maschinen und Geräte Bau 0.15 Std. je m² (Zuschnitt).
do $$
declare
  ot uuid; as_form uuid; as_verbl uuid; fo uuid; hg uuid; polier uuid; garten uuid; geraete uuid; a_tr uuid; kleber uuid;
  ts_src jsonb; af_src jsonb; ao_src jsonb; jz jsonb; ts_neu uuid; af_neu uuid; opt uuid; a_stein uuid;
  stein record; h record; rr int; n int; nart int := 0;
begin
  select id into ot from offertentyp where name = 'Mauern' and papierkorb_am is null;
  select id into as_verbl from arbeitsschritt where offertentyp_id = ot and name = 'Verblender';
  select id into fo from lieferant where name = 'Fontarocca AG';
  select id into hg from lieferant where name = 'HG Commerciale';
  select id into polier from artikel where artikelnummer_knecht = 'KNECHT_000015';
  select id into garten from artikel where artikelnummer_knecht = 'KNECHT_000005';
  select id into geraete from artikel where artikelnummer_knecht = 'KNECHT_000131';
  select id into a_tr from artikel where lieferant_id = fo and artikelnummer_knecht = 'FONTAR_L000';
  if ot is null or as_verbl is null or fo is null or hg is null or polier is null or garten is null or geraete is null or a_tr is null then
    raise exception 'Grundlagen nicht gefunden';
  end if;
  if exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Formsteinmauer') then raise exception 'Formsteinmauer gibt es schon'; end if;

  -- Vorlagen: Teilschritt/Auswahlfeld/Option von Polengranit (Tabellenverweis auf die Mauer-Fläche), Ressourcenzeile von Z-Elemente
  select to_jsonb(t) into ts_src from teilschritt t join arbeitsschritt s on s.id = t.arbeitsschritt_id where s.offertentyp_id = ot and t.name like 'Polengranit Kleinmengen%' limit 1;
  select to_jsonb(f) into af_src from auswahlfeld f join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id where s.offertentyp_id = ot and t.name like 'Polengranit Kleinmengen%' limit 1;
  select to_jsonb(o) into ao_src from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = ot and t.name like 'Polengranit Kleinmengen%' order by o.reihenfolge limit 1;
  select to_jsonb(rz) into jz from ressourcenzeile rz join auswahloption o on o.id = rz.option_id where o.name = 'Z-Elemente Rusted Grey' and rz.reihenfolge = 3;
  if ts_src is null or af_src is null or ao_src is null or jz is null then raise exception 'Vorlagen nicht gefunden'; end if;

  -- Kleber (Preis fehlt, später im Artikelstamm eintragen)
  select id into kleber from artikel where bezeichnung = 'SAKRET Euroflex EF Fliesenkleber flexibel grau 25kg' and lieferant_id = hg;
  if kleber is null then
    kleber := gen_random_uuid();
    insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
    values (kleber, hg, 'material', 'HGC_SAKRET_EUROFLEX_EF', '32412500', 'SAKRET Euroflex EF Fliesenkleber flexibel grau 25kg', 'Sack', null, null, 'CHF', 1, 8.1,
            'Polymervergüteter Flex-Kleber C2-TE, 25 kg Sack, grau. Preis fehlt noch.', false, false, false, true, false);
  end if;

  as_form := gen_random_uuid();
  insert into arbeitsschritt select * from jsonb_populate_record(null::arbeitsschritt,
    (select to_jsonb(s) from arbeitsschritt s where s.id = as_verbl) || jsonb_build_object('id', as_form, 'name', 'Formsteinmauer', 'reihenfolge', 8, 'beschreibung', null, 'titel_offerte', null, 'notiz', null));

  for stein in select * from (values
      (1, 'Maggia Granit Systemmauerwerk', 'MS.001', 'Maggia Granit Systemmauerwerk (Tessin), dunkelgrau, Gneis', 0.5,  0.18, 'm²', 3.2,
          'ca. 18 cm tief, ca. 30-80 cm lang, eine Ansicht gegen Lager gespalten.', null::text),
      (2, 'Ibero Macado',                  'IBERO', 'Ibero Macado (Portugal), grau fein/mittelkorn',                 0.54, 0.20, 'm²', 3.0,
          'ca. 20 cm tief, ca. 40-60 cm lang.', null),
      (3, 'Piasentina Calcit Sediment',    'MS.120', 'Piasentina Calcit Sediment (Italien)',                          0.41, 0.15, 'm²', 3.75,
          'ca. 15 cm tief, 15-50 cm lang.', 'Zuschlag für Mengen unter 10 m² pauschal CHF 180.- (Fontarocca).'),
      (4, 'Jurakalkstein Antico',          'MS.200', 'Jurakalkstein Antico (Deutschland)',                            0.55, 0.22, 't',  1.5,
          'ca. 22 cm tief, freie Längen, Ansicht gekollert/getrommelt.', 'Zuschlag 2 Ansichten 20 %. Zuschlag für Mauerwerk mit über 20 % Anteil an 8 cm hohen Steinen nach Absprache (Fontarocca).')
    ) as v(rf, nm, pre, titel, tm2, tiefe, einheit, ve, bes, hinw)
  loop
    ts_neu := gen_random_uuid(); af_neu := gen_random_uuid();
    insert into teilschritt select * from jsonb_populate_record(null::teilschritt,
      ts_src || jsonb_build_object('id', ts_neu, 'arbeitsschritt_id', as_form, 'name', stein.nm, 'reihenfolge', stein.rf, 'beschreibung', null, 'ausgeblendet', false));
    insert into auswahlfeld select * from jsonb_populate_record(null::auswahlfeld,
      af_src || jsonb_build_object('id', af_neu, 'teilschritt_id', ts_neu, 'name', stein.nm, 'reihenfolge', 1));
    rr := 0;
    for h in select * from (values
        ('Maggia Granit Systemmauerwerk', 8,  'MS.001.610', 452), ('Maggia Granit Systemmauerwerk', 16, 'MS.001.630', 452),
        ('Maggia Granit Systemmauerwerk', 20, 'MS.001.640', 452), ('Maggia Granit Systemmauerwerk', 24, 'MS.001.650', 452),
        ('Ibero Macado', 8,  'IBERO_MACADO_8',  354), ('Ibero Macado', 16, 'IBERO_MACADO_16', 266),
        ('Ibero Macado', 20, 'IBERO_MACADO_20', 257), ('Ibero Macado', 24, 'IBERO_MACADO_24', 251),
        ('Piasentina Calcit Sediment', 20, 'MS.120.740', 349),
        ('Jurakalkstein Antico', 8,  'MS.200.810', 600), ('Jurakalkstein Antico', 16, 'MS.200.830', 582), ('Jurakalkstein Antico', 24, 'MS.200.850', 582)
      ) as x(nm, hoehe, pnr, ep) where x.nm = stein.nm order by x.hoehe
    loop
      select id into a_stein from artikel where lieferant_id = fo and artikelnummer_knecht = 'FONTAR_' || h.pnr;
      if a_stein is null then
        a_stein := gen_random_uuid(); nart := nart + 1;
        insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
        values (a_stein, fo, 'material', 'FONTAR_' || h.pnr, h.pnr,
                'Mauerstein ' || stein.titel || ' Höhe ' || h.hoehe || ' cm, Stoss- und Lagerfugen gesägt', stein.einheit, h.ep, round(h.ep * 1.05), 'CHF', 1, 8.1,
                stein.bes || ' Gewicht ca. ' || (stein.tm2 * 1000)::int || ' kg/m², VE ca. ' || stein.ve || case stein.einheit when 't' then ' t' else ' m²' end || '. Fontarocca Preisliste Mauersteine, Preis je ' || stein.einheit || '.',
                false, false, false, true, false);
      end if;

      rr := rr + 1; opt := gen_random_uuid();
      insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
        ao_src || jsonb_build_object('id', opt, 'auswahlfeld_id', af_neu, 'name', h.hoehe || ' cm', 'reihenfolge', rr,
          'beschreibung', 'Formsteinmauer aus ' || stein.nm || ', Steinhöhe ' || h.hoehe || ' cm (Stoss- und Lagerfugen gesägt), liefern und mit Flexkleber Stein auf Stein verkleben.',
          'hinweistext', 'Preis ab Lager Liestal, Transport von Fontarocca je Tonne separat. ' || stein.bes || coalesce(' ' || stein.hinw, ''),
          'mehrfachauswahl', true, 'ist_standard', false, 'mengenoption', false, 'optionsgruppe_id', null, 'optionsgruppe_name', null));

      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 1, 'kategorie', 'personal', 'artikel_id', polier, 'menge_ausdruck', '{"lit": 1.8, "_einheit": "Std."}'::jsonb, 'notiz', '5 m² pro Tag: 9 Std. / 5 m² = 1.8 Std. je m²'));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 2, 'kategorie', 'personal', 'artikel_id', garten, 'menge_ausdruck', '{"lit": 1.8, "_einheit": "Std."}'::jsonb, 'notiz', '5 m² pro Tag: 9 Std. / 5 m² = 1.8 Std. je m²'));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 3, 'kategorie', 'material', 'artikel_id', a_stein,
        'menge_ausdruck', jsonb_build_object('lit', case stein.einheit when 't' then stein.tm2 else 1 end), 'notiz', case stein.einheit when 't' then 'Gewicht ' || stein.tm2 || ' t je m² Mauerfläche' else '1 m² Stein je m² Mauerfläche' end));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 4, 'kategorie', 'material', 'artikel_id', kleber,
        'menge_ausdruck', jsonb_build_object('lit', round(stein.tiefe / (h.hoehe / 100.0) * 3.3 / 25, 2), '_einheit', 'Sack'),
        'notiz', 'Schätzung: Lagerfuge ' || round(stein.tiefe / (h.hoehe / 100.0), 2) || ' m² je m² Ansicht x 3 kg, +10 % Stossfugen, Sack 25 kg'));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 5, 'kategorie', 'maschine', 'artikel_id', geraete, 'menge_ausdruck', '{"lit": 0.15, "_einheit": "Std."}'::jsonb, 'notiz', 'Zuschnitt, Trennscheibe/Nassfräse, 0.15 Std. je m²'));
      insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt,
        'reihenfolge', 6, 'kategorie', 'logistik', 'artikel_id', a_tr, 'menge_ausdruck', jsonb_build_object('lit', stein.tm2), 'notiz', 'Fontarocca-Lieferung je Tonne: ' || stein.tm2 || ' t je m²'));
    end loop;
  end loop;

  select count(*) into n from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_form;
  if n <> 12 then raise exception 'Erwartet 12 Optionen, angelegt %', n; end if;
  select count(*) into n from ressourcenzeile rz join auswahloption o on o.id = rz.option_id join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id where t.arbeitsschritt_id = as_form;
  if n <> 72 then raise exception 'Erwartet 72 Zeilen, angelegt %', n; end if;
  if nart <> 12 then raise exception 'Erwartet 12 neue Steinartikel, angelegt %', nart; end if;
end $$;
