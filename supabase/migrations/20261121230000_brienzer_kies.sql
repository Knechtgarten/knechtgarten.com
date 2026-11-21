-- Brienzer Kies ab Lager Knecht, CHF 220 pro m³ (Stefan 2026-11-21)
-- Schwimmteich: Arbeitsschritt «Gestaltung mit Kies» (eigene Position), Fläche in m², 10 cm Schicht.
-- Biofilter (Schwimmteich und Pool/Wassergarten «Wasseraufbereitung Bio»): Zusatzoption «Abstreuen mit Brienzer Kies», m².
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool)
select 'db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'material', 'BRIENZERKIES', 'KNECHT_BRIENZERKIES', 'Brienzer Kies ab Lager Knecht', 'm³', 220, 'CHF', 'normal', true, true
where not exists (select 1 from artikel where artikelnummer_knecht = 'KNECHT_BRIENZERKIES');

do $$
declare
  ot uuid := 'bcc55d19-7e61-4fc8-80d0-0889c3148896'; kies uuid; a uuid; t uuid; f uuid; o uuid; fb record;
begin
  select id into kies from artikel where artikelnummer_knecht = 'KNECHT_BRIENZERKIES';

  -- Schwimmteich: Gestaltung mit Kies
  if not exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Gestaltung mit Kies') then
    insert into arbeitsschritt (offertentyp_id, name, reihenfolge) values (ot, 'Gestaltung mit Kies', (select max(reihenfolge) + 1 from arbeitsschritt where offertentyp_id = ot)) returning id into a;
    insert into teilschritt (arbeitsschritt_id, name, reihenfolge) values (a, 'Gestaltung mit Kies', 1) returning id into t;
    insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Kies', 1) returning id into f;
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
    values (f, 'Brienzer Kies', 1, 'Gestaltung mit Brienzer Kies liefern und einbringen (Schicht ca. 10 cm).', 'Fläche in m², Schicht 10 cm. CHF 220 pro m³ ab Lager.', false, true, 'm²', false, true) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, sonderposition_typ_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'material', kies, null, '{"lit": 0.1, "_einheit": "m³"}', 'baukasten', '10 cm Schicht', 1, 1, 1, 1, 1),
      (o, 'logistik', null, '9efee272-85eb-425c-941c-d8569977e592', '{"lit": 0.1}', 'baukasten', 'Kies-Transport', 1, 1, 1, 1, 2),
      (o, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', null, '{"lit": 0.25, "_einheit": "Std."}', 'baukasten', 'Einbringen 0.25 Std./m²', 1, 1, 1, 1, 3);
  end if;

  -- Biofilter in Schwimmteich und Pool: Zusatz «Abstreuen mit Brienzer Kies»
  for fb in select f2.id from auswahlfeld f2 join teilschritt t2 on t2.id = f2.teilschritt_id join arbeitsschritt a2 on a2.id = t2.arbeitsschritt_id
             where (a2.offertentyp_id = ot and t2.name = 'Biofilter') or (a2.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t2.name = 'Wasseraufbereitung Bio') loop
    if exists (select 1 from auswahloption where auswahlfeld_id = fb.id and name = '+ Brienzer Kies') then continue; end if;
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
    values (fb.id, '+ Brienzer Kies', 10, 'Biofilter mit Brienzer Kies abstreuen.', 'Fläche des Biofilters in m², Schicht 10 cm. CHF 220 pro m³ ab Lager.', false, true, 'm²', true, false) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, sonderposition_typ_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'material', kies, null, '{"lit": 0.1, "_einheit": "m³"}', 'baukasten', '10 cm Schicht', 1, 1, 1, 1, 1),
      (o, 'logistik', null, '9efee272-85eb-425c-941c-d8569977e592', '{"lit": 0.1}', 'baukasten', 'Kies-Transport', 1, 1, 1, 1, 2),
      (o, 'personal', '794454dd-c8a4-457a-ab66-b69fa4f6ea81', null, '{"lit": 0.25, "_einheit": "Std."}', 'baukasten', 'Abstreuen 0.25 Std./m²', 1, 1, 1, 1, 3);
  end loop;
end $$;
