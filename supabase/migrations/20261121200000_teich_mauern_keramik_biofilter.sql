-- Naturteich/Schwimmteich: Rückmeldungen Mitarbeiter (Stefan 2026-11-21)
--  1 Kofra-Mauer komplett (wie Pool «Wände betonieren»): Coffra, Beton inkl. Transport, Armierung, Personal – pro m² (Länge × Wassertiefe)
--  2 «Mauerhöhe» heisst «Höhe Natursteinmauer» (gilt nur für Plasselb); Kofra rechnet mit der Wassertiefe
--  3 Natursteinmauern: Hinterfüllung Rundkies 16/32 (30 cm × Höhe) inkl. Einbringen + Kies-Transport,
--    Transport Natursteine ab Lager (Mulde, 10 t je Fuhre) statt gekippt
--  4 Abdeckplatte auf Kofra-Mauer (Piasentina / Geopietra wie Vorlage Mauern), Länge in m
--  5 Keramikplatten: Gummipads 8 mm (5 pro m²) + Transport (0.045 t/m²)
--  6 Biofilter aus Pool/Wassergarten («Wasseraufbereitung Bio») in die Teichtechnik
do $$
declare
  ot uuid := 'bcc55d19-7e61-4fc8-80d0-0889c3148896';
  wt uuid := '8895d24c-2d27-4e50-ad27-de6ab6908e1c';     -- Wassertiefe
  mh uuid := '7c3b0f94-caa4-4be1-8273-77e0a69620c6';     -- Mauerhöhe → Höhe Natursteinmauer
  tpm uuid := '209a8217-b70c-4ff6-8224-ba26c5beb1bd';    -- Tonnen pro m² Natursteinmauer
  kofra uuid := '04d34364-2c4d-4300-bef0-f692b2874d71';
  pool_wand uuid; neu_ts uuid; neu_f uuid; mauern_as uuid; ttech_as uuid; o record; r record; src uuid; dst uuid;
  H jsonb := jsonb_build_object('id', mh, 'ref', 'eingabefeld');
  W jsonb := jsonb_build_object('id', wt, 'ref', 'eingabefeld');
  kies jsonb;
begin
  if exists (select 1 from eingabefeld where id = mh and name = 'Höhe Natursteinmauer') then raise notice 'schon gemacht'; return; end if;

  -- 2 Feld umbenennen, Kofra-Sprühkleber auf Wassertiefe
  update eingabefeld set name = 'Höhe Natursteinmauer', erklaerung = 'Sichtbare Höhe der Natursteinmauer (Plasselb). Die Kofra-Mauer rechnet mit der Wassertiefe.' where id = mh;
  update ressourcenzeile set menge_ausdruck = replace(menge_ausdruck::text, mh::text, wt::text)::jsonb,
         menge_formel_baukasten_ausdruck = case when menge_formel_baukasten_ausdruck is null then null else replace(menge_formel_baukasten_ausdruck::text, mh::text, wt::text)::jsonb end
   where option_id = kofra;

  -- 1 Kofra: Zeilen aus Pool «Wände betonieren» (pro m² Wand) → pro m Mauer × Wassertiefe
  select o2.id into pool_wand from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
   where a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and o2.name = 'Wände betonieren';
  insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, menge_formel_baukasten_ausdruck, preis_override, notiz,
    zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
  select kofra, r2.kategorie, r2.artikel_id, r2.bezeichnung_override,
    replace(replace(r2.menge_ausdruck::text, '{"id": "bff364d7-0ec3-423a-9443-499909937aa4", "ref": "term"}', W::text),
            '{"id": "cb48054f-2668-400b-8bea-29789b3ecef7", "ref": "term"}', '{"lit": 1}')::jsonb,
    null, r2.preis_override, r2.notiz, r2.zugang_stufe1, r2.zugang_stufe2, r2.zugang_stufe3, r2.zugang_stufe4, r2.mindestmenge, r2.verschnitt_prozent, r2.sonderposition_typ_id,
    10 + r2.reihenfolge, 'baukasten',
    -- feste Mengen (Restbeton, Schmiermischung, Kran) einmal pro Offerte, nicht pro Laufmeter
    r2.menge_ausdruck ? 'lit'
  from ressourcenzeile r2 where r2.option_id = pool_wand and (r2.artikel_id is not null or r2.sonderposition_typ_id is not null);

  -- 3 Natursteinmauern: Hinterfüllung + Transport ab Lager
  kies := jsonb_build_object('op', '*', 'args', jsonb_build_array(H, '{"lit": 0.3}'::jsonb));   -- m³ pro m Mauer
  for o in select o2.id from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
            where a.offertentyp_id = ot and a.name = 'Mauern' and t.name in ('Mauer wechselschichtig', 'Mauer geschichtet') loop
    insert into ressourcenzeile (option_id, kategorie, artikel_id, sonderposition_typ_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o.id, 'material', (select id from artikel where artikelnummer_knecht = 'KIEHEIM_203'), null, kies, 'baukasten', 'Hinterfüllung 30 cm × Mauerhöhe', 1, 1, 1, 1, 50),
      (o.id, 'logistik', null, '9efee272-85eb-425c-941c-d8569977e592', kies, 'baukasten', 'Kies-Transport Hinterfüllung', 1, 1, 1, 1, 51),
      (o.id, 'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a', null, jsonb_build_object('op', '*', 'args', jsonb_build_array(kies, '{"lit": 0.8}'::jsonb)), 'baukasten', 'Hinterfüllung einbringen 0.8 Std./m³', 1, 1, 1, 1, 52),
      (o.id, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', null, jsonb_build_object('op', '*', 'args', jsonb_build_array(kies, '{"lit": 0.8}'::jsonb)), 'baukasten', 'Hinterfüllung einbringen 0.8 Std./m³', 1, 1, 1, 1, 53),
      (o.id, 'logistik', (select id from artikel where bezeichnung = 'Zwischentransport Mulde Natursteine (10 t je Fuhre)' limit 1), null,
        jsonb_build_object('op', '/', 'args', jsonb_build_array(jsonb_build_object('op', '*', 'args', jsonb_build_array(jsonb_build_object('id', tpm, 'ref', 'term'), H)), '{"lit": 10}'::jsonb)),
        'baukasten', 'Transport Natursteine ab Lager, 10 t je Fuhre', 1, 1, 1, 1, 54);
  end loop;

  -- 4 Abdeckplatte auf Kofra-Mauer: neue Teilschritt mit den Abdeckungen aus der Vorlage Mauern (Länge in m)
  select id into mauern_as from arbeitsschritt where offertentyp_id = ot and name = 'Mauern';
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge, beschreibung) values (mauern_as, 'Abdeckplatte auf Kofra-Mauer', 10, 'Abdeckung, wenn die Kofra-Mauer auf 1 oder 2 Seiten sichtbar ist.') returning id into neu_ts;
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (neu_ts, 'Abdeckplatte', 1) returning id into neu_f;
  for o in select o2.* from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
            where a.offertentyp_id = 'e1151980-a708-4a62-a555-e15853ed48c9' and o2.name in ('Abdeckung Piasentina', 'Abdeckung Geopietra') order by o2.reihenfolge loop
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, hinweisbild_url, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
    values (neu_f, replace(o.name, 'Abdeckung ', ''), o.reihenfolge, o.beschreibung, o.hinweistext, o.hinweisbild_url, false, true, 'm', false, o.ist_eigene_offertenposition) returning id into dst;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
    select dst, r2.kategorie, r2.artikel_id, r2.bezeichnung_override, r2.menge_ausdruck, r2.preis_override, r2.notiz, r2.zugang_stufe1, r2.zugang_stufe2, r2.zugang_stufe3, r2.zugang_stufe4, r2.mindestmenge, r2.verschnitt_prozent, r2.sonderposition_typ_id, r2.reihenfolge, coalesce(r2.menge_formel_modus, 'baukasten'), r2.mengenoption_ausgenommen
    from ressourcenzeile r2 where r2.option_id = o.id;
  end loop;

  -- 5 Keramikplatten: Gummipads + Transport
  for o in select o2.id from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
            where a.offertentyp_id = ot and o2.name = 'Keramikplatte auf Betonplatte' loop
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o.id, 'material', (select id from artikel where artikelnummer_knecht = 'IMMER_79.2163.0008'), '{"op": "*", "args": [{"id": "02e64ce2-efee-4fc5-911c-7a9e4c3ca595", "ref": "term"}, {"lit": 5}]}', 'baukasten', 'Gummipads 5 pro m²', 1, 1, 1, 1, 60),
      (o.id, 'logistik', (select id from artikel where artikelnummer_knecht = 'FONTAR_L000'), '{"op": "*", "args": [{"id": "02e64ce2-efee-4fc5-911c-7a9e4c3ca595", "ref": "term"}, {"lit": 0.045}]}', 'baukasten', 'Transport Platten ca. 45 kg/m²', 1, 1, 1, 1, 61);
  end loop;

  -- 6 Biofilter in die Teichtechnik (Kopie der Teilschritt «Wasseraufbereitung Bio» aus Pool/Wassergarten)
  select id into ttech_as from arbeitsschritt where offertentyp_id = ot and name = 'Teichtechnik';
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge, beschreibung) values (ttech_as, 'Biofilter', 5, null) returning id into neu_ts;
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (neu_ts, 'Biofilter', 1) returning id into neu_f;
  for o in select o2.* from auswahloption o2 join auswahlfeld f on f.id = o2.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
            where a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t.name = 'Wasseraufbereitung Bio' order by o2.reihenfolge loop
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, hinweisbild_url, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
    values (neu_f, o.name, o.reihenfolge, o.beschreibung, o.hinweistext, o.hinweisbild_url, false, o.mengenoption, o.mengenoption_einheit, o.mehrfachauswahl, o.ist_eigene_offertenposition) returning id into dst;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
    select dst, r2.kategorie, r2.artikel_id, r2.bezeichnung_override, r2.menge_ausdruck, r2.preis_override, r2.notiz, r2.zugang_stufe1, r2.zugang_stufe2, r2.zugang_stufe3, r2.zugang_stufe4, r2.mindestmenge, r2.verschnitt_prozent, r2.sonderposition_typ_id, r2.reihenfolge, coalesce(r2.menge_formel_modus, 'baukasten'), r2.mengenoption_ausgenommen
    from ressourcenzeile r2 where r2.option_id = o.id;
  end loop;
end $$;
