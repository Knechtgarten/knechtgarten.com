-- Vorlage Mauern:
-- 1) Transport (Artikel «Transport Natursteinplatten», CHF/t) auch bei Verblendern und Abdeckungen.
--    Gewichte geschätzt: Stonepanel 45 kg/m², Geopietra 55 kg/m², Piasentina 3 cm 80 kg/m² (0.4 m²/m = 32 kg/m),
--    Geopietra-Abdeckung 36x100 ca. 35 kg/m. In Tool B anpassbar.
-- 2) Option «Gemischt» bei Jurakalkstein, Maggia, Ibero: 20 % 8 cm · 50 % 16 cm · 30 % 24 cm der Fläche
--    (alle Zeilen der drei Höhen anteilig: Stein, Kleber, Transport, Stunden).
do $$
declare
  vorlage_transport uuid := 'f811a830-feac-4d9e-af90-024b2e770b4d'; -- Transportzeile Jura 8 cm
  t record; o8 record; neu uuid; anteil numeric; hoehe text;
begin
  -- 1) Transport ergänzen (nur wenn noch keine Transportzeile da ist)
  for t in select * from (values
      ('1c93a357-0c63-46b3-ac4a-759b619a9b3b'::uuid, 0.045), -- Rusted Grey
      ('fcad31f7-3772-4e64-aa32-759222e08195'::uuid, 0.045), -- Rusted Brown
      ('7d1d93c2-422e-4d32-af3d-73edffd6b0e1'::uuid, 0.055), -- Geopietra Toce
      ('e1822107-16b5-401e-950a-c4ea1d017fed'::uuid, 0.055), -- Geopietra Cascata
      ('488338df-92f5-4c47-947e-7c938765833c'::uuid, 0.032), -- Abdeckung Piasentina (pro m)
      ('758c3902-4d67-4215-9f71-5024a241585b'::uuid, 0.035)  -- Abdeckung Geopietra (pro m)
    ) as x(oid, tonnen)
  loop
    if not exists (select 1 from ressourcenzeile r where r.option_id = t.oid and r.artikel_id = (select artikel_id from ressourcenzeile where id = vorlage_transport)) then
      insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, menge_formel_baukasten_ausdruck,
        zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, ist_eigene_offertenposition, mengenoption_ausgenommen)
      select t.oid, v.kategorie, v.artikel_id, jsonb_build_object('lit', t.tonnen), 'baukasten', jsonb_build_object('lit', t.tonnen),
        v.zugang_stufe1, v.zugang_stufe2, v.zugang_stufe3, v.zugang_stufe4,
        coalesce((select max(reihenfolge) from ressourcenzeile where option_id = t.oid), 0) + 1, false, false
      from ressourcenzeile v where v.id = vorlage_transport;
    end if;
  end loop;

  -- 2) «Gemischt»
  for o8 in
    select o.* from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
    where ts.name in ('Jurakalkstein Antico', 'Maggia Granit Systemmauerwerk', 'Ibero Macado') and o.name = '8 cm'
      and not exists (select 1 from auswahloption g where g.auswahlfeld_id = o.auswahlfeld_id and g.name = 'Gemischt')
  loop
    insert into auswahloption (auswahlfeld_id, name, beschreibung, reihenfolge, mengenoption, mengenoption_einheit, mengenoption_standardmenge,
      tabellenverweis, mehrfachauswahl, ist_standard, ist_eigene_offertenposition, hinweistext)
    values (o8.auswahlfeld_id, 'Gemischt',
      replace(o8.beschreibung, 'Steinhöhe 8 cm', 'gemischte Steinhöhen 8/16/24 cm'),
      (select max(reihenfolge) + 1 from auswahloption where auswahlfeld_id = o8.auswahlfeld_id),
      o8.mengenoption, o8.mengenoption_einheit, o8.mengenoption_standardmenge, o8.tabellenverweis, o8.mehrfachauswahl, false, false,
      'Gemischt: 20 % 8 cm · 50 % 16 cm · 30 % 24 cm (Anteil an der Fläche).' || coalesce(' ' || o8.hinweistext, ''))
    returning id into neu;
    for hoehe, anteil in select * from (values ('8 cm', 0.2), ('16 cm', 0.5), ('24 cm', 0.3)) as h(n, a) loop
      insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz,
        zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, teilschritt_id, mindestmenge, verschnitt_prozent,
        staffelgruppe_id, zonengruppe_id, sonderposition_typ_id, tagesleistung_menge, reihenfolge, ist_eigene_offertenposition,
        zuschlag_prozent, menge_formel_modus, menge_formel_text, menge_formel_baukasten_ausdruck, auswahlgruppe_id, mengenoption_ausgenommen)
      select neu, r.kategorie, r.artikel_id, r.bezeichnung_override,
        jsonb_build_object('op', '*', 'args', jsonb_build_array(r.menge_ausdruck, jsonb_build_object('lit', anteil))), r.preis_override, r.notiz,
        r.zugang_stufe1, r.zugang_stufe2, r.zugang_stufe3, r.zugang_stufe4, null, r.mindestmenge, r.verschnitt_prozent,
        r.staffelgruppe_id, r.zonengruppe_id, r.sonderposition_typ_id, r.tagesleistung_menge, r.reihenfolge, r.ist_eigene_offertenposition,
        r.zuschlag_prozent, r.menge_formel_modus, r.menge_formel_text,
        case when r.menge_formel_baukasten_ausdruck is null then null
             else jsonb_build_object('op', '*', 'args', jsonb_build_array(r.menge_formel_baukasten_ausdruck, jsonb_build_object('lit', anteil))) end,
        r.auswahlgruppe_id, r.mengenoption_ausgenommen
      from ressourcenzeile r join auswahloption o on o.id = r.option_id
      where o.auswahlfeld_id = o8.auswahlfeld_id and o.name = hoehe;
    end loop;
  end loop;
end $$;
