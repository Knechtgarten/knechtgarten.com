-- Helikopter als Alternative zum Kran (Stefan 2026-11-21), Verkauf = Einkauf × 1.2 (20 % Marge)
--  Air Glaciers (Lasten bis ca. 1000 kg), Rechnung 167345 vom 22.10.2026: Überflug Regionalprogramm 180.–, Flugminute 42.– + 4 % Kerosin
--  Rotex Helicopter K-Max (über 1000 kg bis 2.5 t), Rechnung 79459 vom 01.04.2026 (Pool Stavro, Muri, 1.8 t): Einsatz pauschal 3'900.–
-- Optionen: Regenwassertank › Zusatzarbeiten › Kranarbeiten und Pool › Beckeneinbau › Beckenkörper PP und Edelstahl
-- (gleiche Arbeit wie die Kran-Option «20 m» bzw. «4-Achs (20 m)», statt Kran der Helikopter).
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select 'db9c6bd1-ee9d-40a4-9d1f-723faba51728', 'logistik', v.lnr, v.nr, v.bez, v.eh, v.ep, round(v.ep * 1.2, 2), 'CHF', 'normal', true, true, v.notiz
from (values
  ('AG-UEBERFLUG', 'HELI_AIRGLACIERS_UEBERFLUG', 'Helikopter Air Glaciers: Überflug Regionalprogramm (pauschal)', 'Stk.', 180::numeric, 'Air Glaciers Lauterbrunnen, Rechnung 167345 (Okt. 2026)'),
  ('AG-MINUTE', 'HELI_AIRGLACIERS_MINUTE', 'Helikopter Air Glaciers: Flugminute (Rotationen, inkl. 4 % Kerosin)', 'Min.', 43.68, 'Air Glaciers 42.– pro Min. + 4 % Kerosin-Aufschlag'),
  ('ROTEX-KMAX', 'HELI_ROTEX_KMAX', 'Helikopter Rotex K-Max (Lasten über 1000 kg bis 2.5 t): Einsatz pauschal inkl. Überflug, Installation, AVOR, Reko, 1 Rotation', 'Stk.', 3900, 'Rotex Helicopter, Rechnung 79459 (Apr. 2026, Pool Stavro Muri 1.8 t)')
) v(lnr, nr, bez, eh, ep, notiz)
where not exists (select 1 from artikel a where a.artikelnummer_knecht = v.nr);

do $$
declare
  vorlage record; neu uuid; ag_u uuid; ag_m uuid; rx uuid;
begin
  select id into ag_u from artikel where artikelnummer_knecht = 'HELI_AIRGLACIERS_UEBERFLUG';
  select id into ag_m from artikel where artikelnummer_knecht = 'HELI_AIRGLACIERS_MINUTE';
  select id into rx   from artikel where artikelnummer_knecht = 'HELI_ROTEX_KMAX';
  -- Vorlage-Option pro Ort: Arbeit übernehmen, Kran-Zeilen weglassen
  for vorlage in
    select o.*, x.min from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
    join (values ('Regenwassertank', 'Kranarbeiten', '4-Achs (20 m)', 5), ('Pool/Wassergarten', 'Beckenkörper PP und Edelstahl', '20 m', 6)) x(typ, ts, opt, min)
      on t.name = x.ts and o.name = x.opt and a.offertentyp_id = (select id from offertentyp where name = x.typ)
  loop
    if exists (select 1 from auswahloption where auswahlfeld_id = vorlage.auswahlfeld_id and name like 'Helikopter%') then continue; end if;
    -- Air Glaciers
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition, optionsgruppe_id, optionsgruppe_name)
    values (vorlage.auswahlfeld_id, 'Helikopter bis 1000 kg', 90, replace(replace(coalesce(vorlage.beschreibung, ''), 'mit Kranwagen', 'mit Helikopter'), 'des Krans', 'des Helikopters'),
      'Air Glaciers: Überflug pauschal + Flugminuten (Annahme ' || vorlage.min || ' Min.). Für Lasten bis ca. 1000 kg.', false, false, vorlage.mengenoption_einheit, vorlage.mehrfachauswahl, vorlage.ist_eigene_offertenposition, vorlage.optionsgruppe_id, vorlage.optionsgruppe_name)
    returning id into neu;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
    select neu, r.kategorie, r.artikel_id, r.bezeichnung_override, r.menge_ausdruck, r.preis_override, r.notiz, r.zugang_stufe1, r.zugang_stufe2, r.zugang_stufe3, r.zugang_stufe4, r.mindestmenge, r.verschnitt_prozent, r.sonderposition_typ_id, r.reihenfolge, coalesce(r.menge_formel_modus, 'baukasten'), r.mengenoption_ausgenommen
    from ressourcenzeile r left join artikel a on a.id = r.artikel_id where r.option_id = vorlage.id and not (coalesce(a.bezeichnung, '') ilike any (array['%kranwagen%', '%pneukran%']));
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (neu, 'logistik', ag_u, '{"lit": 1, "_einheit": "Stk."}', 'baukasten', 1, 1, 1, 1, 90),
      (neu, 'logistik', ag_m, jsonb_build_object('lit', vorlage.min, '_einheit', 'Min.'), 'baukasten', 1, 1, 1, 1, 91);
    -- Rotex
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition, optionsgruppe_id, optionsgruppe_name)
    values (vorlage.auswahlfeld_id, 'Helikopter über 1000 kg', 91, replace(replace(coalesce(vorlage.beschreibung, ''), 'mit Kranwagen', 'mit Helikopter'), 'des Krans', 'des Helikopters'),
      'Rotex K-Max: Einsatz pauschal inkl. Überflug, Installation, AVOR, Reko, 1 Rotation. Für Lasten über 1000 kg bis 2.5 t (z. B. grosse Becken).', false, false, vorlage.mengenoption_einheit, vorlage.mehrfachauswahl, vorlage.ist_eigene_offertenposition, vorlage.optionsgruppe_id, vorlage.optionsgruppe_name)
    returning id into neu;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, bezeichnung_override, menge_ausdruck, preis_override, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, mindestmenge, verschnitt_prozent, sonderposition_typ_id, reihenfolge, menge_formel_modus, mengenoption_ausgenommen)
    select neu, r.kategorie, r.artikel_id, r.bezeichnung_override, r.menge_ausdruck, r.preis_override, r.notiz, r.zugang_stufe1, r.zugang_stufe2, r.zugang_stufe3, r.zugang_stufe4, r.mindestmenge, r.verschnitt_prozent, r.sonderposition_typ_id, r.reihenfolge, coalesce(r.menge_formel_modus, 'baukasten'), r.mengenoption_ausgenommen
    from ressourcenzeile r left join artikel a on a.id = r.artikel_id where r.option_id = vorlage.id and not (coalesce(a.bezeichnung, '') ilike any (array['%kranwagen%', '%pneukran%']));
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (neu, 'logistik', rx, '{"lit": 1, "_einheit": "Stk."}', 'baukasten', 1, 1, 1, 1, 90);
  end loop;
end $$;

-- Regenwassertank: Schieberegler «Zugänglichkeit Standort» einschalten (Maschinen haben die Faktoren 0.8 / 1 / 1.2 / 1.4 schon)
update offertentyp set zugaenglichkeit_aktiv = true where name = 'Regenwassertank';

-- Korrektur (erster Lauf hatte die Kran-Zeilen mitkopiert)
delete from ressourcenzeile r using artikel a, auswahloption o
where a.id = r.artikel_id and o.id = r.option_id and o.name like 'Helikopter%' and (a.bezeichnung ilike '%kranwagen%' or a.bezeichnung ilike '%pneukran%');
