-- Artikel "Maschinen und Geraete Bau" (KNECHT_000131, Trennscheibe, Ruettelplatte, Vibronadel usw.) bei allen Positionen
-- ergaenzen, wo verdichtet, geschnitten oder betoniert wird. Menge je nach Position fix (Std.) oder nach Menge
-- (Std. pro m2 / m / m3). Fixe Zeilen sind von der Mengenoption/Flaechentabelle ausgenommen.
-- Optionen, die den Artikel schon haben, werden uebersprungen.
create or replace function pg_temp.add_geraete(
  p_typ text, p_as text[], p_af text[], p_opt text[],
  p_menge jsonb, p_mindest numeric, p_ausg boolean, p_notiz text, p_erwartet int
) returns int language plpgsql as $f$
declare
  geraete uuid; o record; jz jsonb; mx int; n int := 0;
begin
  select id into geraete from artikel where artikelnummer_knecht = 'KNECHT_000131';
  if geraete is null then raise exception 'Artikel KNECHT_000131 nicht gefunden'; end if;
  for o in
    select ao.id from auswahloption ao
      join auswahlfeld af on af.id = ao.auswahlfeld_id
      join teilschritt ts on ts.id = af.teilschritt_id
      join arbeitsschritt s on s.id = ts.arbeitsschritt_id
      join offertentyp ot on ot.id = s.offertentyp_id
     where ot.name = p_typ and ot.papierkorb_am is null
       and (p_as is null or s.name = any(p_as))
       and (p_af is null or af.name = any(p_af))
       and (p_opt is null or ao.name = any(p_opt))
  loop
    n := n + 1;
    if exists (select 1 from ressourcenzeile z where z.option_id = o.id and z.artikel_id = geraete) then continue; end if;
    select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = o.id
      order by (rz.kategorie = 'material') desc, rz.reihenfolge limit 1;
    if jz is null then raise exception 'Option % hat keine Zeile als Vorlage', o.id; end if;
    select max(reihenfolge) into mx from ressourcenzeile where option_id = o.id;
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', mx + 1, 'kategorie', 'maschine', 'artikel_id', geraete,
        'menge_ausdruck', p_menge, 'mindestmenge', p_mindest, 'mengenoption_ausgenommen', p_ausg, 'notiz', p_notiz,
        'menge_formel_modus', 'baukasten', 'menge_formel_text', null, 'menge_formel_baukasten_ausdruck', null,
        'verschnitt_prozent', null, 'zuschlag_prozent', null, 'preis_override', null, 'bezeichnung_override', null,
        'staffelgruppe_id', null, 'zonengruppe_id', null, 'auswahlgruppe_id', null, 'sonderposition_typ_id', null,
        'tagesleistung_menge', null, 'ist_eigene_offertenposition', false));
  end loop;
  if p_erwartet is not null and n <> p_erwartet then
    raise exception 'Auswahl % / % / %: erwartet % Optionen, gefunden %', p_typ, p_as, p_af, p_erwartet, n;
  end if;
  return n;
end $f$;

do $$
declare
  t int := 0;
begin
  -- ===== Belaege, Hartflaechen =====
  t := t + pg_temp.add_geraete('Beläge, Hartflächen', null, array['Pflastersteine in Splittbeton','Pflastersteine in Splitt'], null,
        '{"lit": 0.04, "_einheit": "Std."}', null, false, 'Rütteln der Pflästerung, 0.04 Std. pro m²', 10);
  t := t + pg_temp.add_geraete('Beläge, Hartflächen', null, array['Randbefestigung'], array['Randabschluss Granit','Randabschluss Guber','Randabschluss Luserna','Randbeton'],
        '{"lit": 0.1, "_einheit": "Std."}', 1, false, 'Schneiden und Setzen, 0.1 Std. pro Laufmeter, mind. 1 Std.', 4);
  t := t + pg_temp.add_geraete('Beläge, Hartflächen', null, array['Kiesfläche'], null,
        '{"lit": 0.008, "_einheit": "Std."}', 1, false, 'Verdichten Mergel: 0.08 m³/m² × 0.1 Std./m³, mind. 1 Std.', 2);
  t := t + pg_temp.add_geraete('Beläge, Hartflächen', null, array['Natursteinbelag formwild'], null,
        '{"lit": 1, "_einheit": "Std."}', null, true, 'Zuhauen, 1 Std. pauschal', 2);

  -- ===== Mauern =====
  t := t + pg_temp.add_geraete('Mauern', null, array['Fundation'], array['Beton LKW gepumpt','Beton Lieferwagen'],
        '{"lit": 1, "_einheit": "Std."}', null, true, 'Vibronadel, 1 Std. pauschal', 2);
  t := t + pg_temp.add_geraete('Mauern', null, array['Hinterfüllung Kies'], null,
        '{"op": "*", "args": [{"id": "95ff1a02-13b7-40f8-a67a-7c83c9cd66a3", "ref": "term"}, {"lit": 0.1, "_einheit": "Std."}]}'::jsonb, 1, false, 'Stampfer/Rüttelplatte, 0.1 Std. pro m³ Kies, mind. 1 Std.', 4);
  t := t + pg_temp.add_geraete('Mauern', null, array['Hinterfüllung Sickerbeton'], null,
        '{"lit": 1, "_einheit": "Std."}', null, true, 'Vibronadel, 1 Std. pauschal', 3);
  t := t + pg_temp.add_geraete('Mauern', null, array['Natursteinmauer Plasselb wechselschichtig'], array['von Hand','Kran -20m','Kran -30m','Kran -45m'],
        '{"op": "*", "args": [{"id": "d5e7a229-90df-4ca6-8820-8804c996d585", "ref": "term"}, {"lit": 0.1, "_einheit": "Std."}]}'::jsonb, null, false, 'Trennscheibe/Zuhauen, 0.1 Std. pro m² Sichtfläche', 4);
  t := t + pg_temp.add_geraete('Mauern', null, array['Polengranit Grossmengen franko geliefert','Polengranit Kleinmengen ab Lager Liestal'], null,
        '{"lit": 0.1, "_einheit": "Std."}', null, false, 'Trennscheibe, 0.1 Std. pro m² Mauerfläche', null);
  t := t + pg_temp.add_geraete('Mauern', null, array['Verblender Geopietra','Verblender Z-Elemente'], null,
        '{"lit": 0.15, "_einheit": "Std."}', null, false, 'Trennscheibe/Nassfräse, 0.15 Std. pro m²', 4);
  t := t + pg_temp.add_geraete('Mauern', null, array['Zusatzarbeiten Blendmauer'], array['Abdeckplatte Piasentina','Geopietra Abdeckung'],
        '{"op": "*", "args": [{"id": "219085c9-2abd-45de-b15e-f527f67e4b39", "ref": "term"}, {"lit": 0.1, "_einheit": "Std."}]}'::jsonb, null, false, 'Trennscheibe, 0.1 Std. pro Laufmeter Abdeckung', 2);

  -- ===== Holzdeck =====
  t := t + pg_temp.add_geraete('Holzdeck', null, array['Holzdeck inkl. Aluprofile'], null,
        '{"op": "*", "args": [{"id": "bbd0a349-74eb-480e-9bb7-586f5f09fc84", "ref": "spalte"}, {"lit": 0.1, "_einheit": "Std."}]}'::jsonb, 1, false, 'Kappsäge/Zuschnitt, 0.1 Std. pro m², mind. 1 Std.', 5);
  t := t + pg_temp.add_geraete('Holzdeck', array['Treppenelemente','Sitzelement','Stirnverkleidung'], null, null,
        '{"lit": 1, "_einheit": "Std."}', null, true, 'Zuschnitt, 1 Std. pauschal', 19);

  -- ===== Pool/Wassergarten =====
  t := t + pg_temp.add_geraete('Pool/Wassergarten', null, array['Betonkragen'], null,
        '{"lit": 1.5, "_einheit": "Std."}', null, true, 'Vibronadel, 1.5 Std. pauschal', 2);
  t := t + pg_temp.add_geraete('Pool/Wassergarten', null, array['Hinterfüllung'], array['Sickerbeton','Rundkies'],
        '{"op": "*", "args": [{"id": "f4170c78-5b08-47a6-a4db-b909adfa2dfa", "ref": "term"}, {"lit": 0.1, "_einheit": "Std."}]}'::jsonb, 1, false, 'Verdichten, 0.1 Std. pro m³, mind. 1 Std.', 2);
  t := t + pg_temp.add_geraete('Pool/Wassergarten', null, array['Beckenkörper PP und Edelstahl'], array['Beckeneinbau 15m','Beckeneinbau 20m','Beckeneinbau 27m','Beckeneinbau 31m','Beckeneinbau 45m'],
        '{"lit": 2, "_einheit": "Std."}', null, true, 'Zuschnitt/Justieren, 2 Std. pauschal', 5);
  t := t + pg_temp.add_geraete('Pool/Wassergarten', null, array['Verrohrung Übergabepunkt-Technikstandort'], array['1 - 3 Leitungen','4-6 Leitungen','6-9 Leitungen','2-4 Leitungen Bio Geberit'],
        '{"lit": 0.5, "_einheit": "Std."}', null, true, 'Rohrschneider, 0.5 Std. pauschal', 4);
  t := t + pg_temp.add_geraete('Pool/Wassergarten', null, array['Schränke, Boxen'], null,
        '{"lit": 1, "_einheit": "Std."}', null, true, 'Fundament, 1 Std. pauschal', 6);

  -- ===== Bewaesserung =====
  t := t + pg_temp.add_geraete('Bewässerung', null, array['Grabarbeiten usw. inkl Material'], null,
        '{"lit": 0.5, "_einheit": "Std."}', null, true, 'Verdichten der Gräben, 0.5 Std. pro Einsatz', 2);

  -- ===== Regenwassertank: Anschlussleitungen graben (pro Tageseinsatz) =====
  t := t + pg_temp.add_geraete('Regenwassertank', array['Zusatzarbeiten'], array['Zusatzarbeiten'], array['Bagger S','Bagger M','Bagger L'],
        '{"lit": 1, "_einheit": "Std."}', null, false, 'Verdichten, 1 Std. pro Tageseinsatz', 3);

  raise notice 'Optionen bearbeitet: %', t;
end $$;
