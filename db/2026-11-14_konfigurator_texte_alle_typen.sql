-- Konfigurator-Knöpfe aller Offertentypen kürzer (wie Pool/Wassergarten): Wort aus dem Balken nicht wiederholen,
-- Reihen (L/M/S, Distanzen, Modelle) als Optionsgruppe (nur ohne Mehrfachauswahl), Details ins Mouse-over.
-- Nur Namen, Mouse-over und Gruppen – Rechnung unverändert.
create temp table _grp (typ text, feld text, grp text, id uuid default gen_random_uuid(), primary key (typ, feld, grp));

create or replace function pg_temp.r(p_typ text, p_feld text, p_alt text, p_neu text, p_hint text default null, p_grp text default null) returns void language plpgsql as $f$
declare n int; g uuid;
begin
  if p_grp is not null then
    insert into _grp(typ, feld, grp) values (p_typ, p_feld, p_grp) on conflict do nothing;
    select id into g from _grp where typ = p_typ and feld = p_feld and grp = p_grp;
  end if;
  update auswahloption o set
    name = p_neu,
    hinweistext = case when p_hint is null then o.hinweistext
                       when coalesce(o.hinweistext, '') = '' then p_hint
                       when position(p_hint in o.hinweistext) > 0 then o.hinweistext
                       else p_hint || E'\n' || o.hinweistext end,
    optionsgruppe_name = case when p_grp is not null and not o.mehrfachauswahl then p_grp else o.optionsgruppe_name end,
    optionsgruppe_id = case when p_grp is not null and not o.mehrfachauswahl then g else o.optionsgruppe_id end
  from auswahlfeld f, teilschritt t, arbeitsschritt a, offertentyp ot
  where o.auswahlfeld_id = f.id and f.teilschritt_id = t.id and t.arbeitsschritt_id = a.id and a.offertentyp_id = ot.id
    and ot.name = p_typ and f.name = p_feld and o.name = p_alt and ot.papierkorb_am is null;
  get diagnostics n = row_count;
  if n = 0 then raise notice 'nicht gefunden: % / % / %', p_typ, p_feld, p_alt; end if;
end $f$;

-- Aushub (gleich in Beläge, Holzdeck, Mauern, Naturteich)
do $$ declare t text; begin
  foreach t in array array['Beläge, Hartflächen', 'Holzdeck', 'Mauern', 'Naturteich/Schwimmteich'] loop
    perform pg_temp.r(t, 'Aushubarbeiten', 'Baumaschinen L', 'L', null, 'Baumaschinen');
    perform pg_temp.r(t, 'Aushubarbeiten', 'Baumaschinen M', 'M', null, 'Baumaschinen');
    perform pg_temp.r(t, 'Aushubarbeiten', 'Baumaschinen S', 'S', null, 'Baumaschinen');
    perform pg_temp.r(t, 'Aushubarbeiten', 'Kranaushub -20m', 'bis 20 m', null, 'Kranaushub');
    perform pg_temp.r(t, 'Aushubarbeiten', 'Kranaushub -30m', 'bis 30 m', null, 'Kranaushub');
    perform pg_temp.r(t, 'Aushubarbeiten', 'Kranaushub -45m', 'bis 45 m', null, 'Kranaushub');
    perform pg_temp.r(t, 'Aushub Abtransport', 'Abtransport Mulde LKW', 'Mulde LKW');
    perform pg_temp.r(t, 'Aushub Abtransport', 'Abtransport Lieferwagen', 'Lieferwagen');
  end loop;
end $$;

-- Beläge, Hartflächen
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Baumaschinen L', 'L', null, 'Baumaschinen');
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Baumaschinen M', 'M', null, 'Baumaschinen');
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Baumaschinen S', 'S', null, 'Baumaschinen');
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Kran Kieseinbau -20m', 'bis 20 m', null, 'Kran');
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Kran Kieseinbau -30m', 'bis 30 m', null, 'Kran');
select pg_temp.r('Beläge, Hartflächen', 'Fundation Kieseinbau LKW', 'Kran Kieseinbau -45m', 'bis 45 m', null, 'Kran');
select pg_temp.r('Beläge, Hartflächen', 'Fugen', 'PF1 Platten formwild und Bahnen', 'PF1 formwild/Bahnen', 'PF1 für Platten formwild und Bahnen');

-- Holzdeck
select pg_temp.r('Holzdeck', 'Fundation', 'Fundation Kieseinbau LKW', 'Kieseinbau LKW');
select pg_temp.r('Holzdeck', 'Fundation', 'Fundation Kieseinbau Lieferwagen', 'Kieseinbau LW', 'Kieseinbau mit Lieferwagen');
select pg_temp.r('Holzdeck', 'Holzdeck inkl. Aluprofile', 'Thermo Kiefer', 'Thermokiefer');
select pg_temp.r('Holzdeck', 'Stirnverkleidung', 'Stirnbrett Accoya Natur', 'Accoya Natur', 'Stirnbrett');
select pg_temp.r('Holzdeck', 'Stirnverkleidung', 'Stirnbrett Accoya grau', 'Accoya grau', 'Stirnbrett');
select pg_temp.r('Holzdeck', 'Stirnverkleidung', 'Stirnbrett Douglasie', 'Douglasie', 'Stirnbrett');
select pg_temp.r('Holzdeck', 'Stirnverkleidung', 'Stirnbrett Thermo Kiefer', 'Thermokiefer', 'Stirnbrett');
select pg_temp.r('Holzdeck', 'Deckel ca. 1mx1m', 'Technikdeckel Scharnier einflüglig', 'Scharnier 1-flüglig', 'Technikdeckel mit Scharnier, einflüglig');
select pg_temp.r('Holzdeck', 'Deckel ca. 1mx1m', 'Technikdeckel Scharnier Zweiflüglig', 'Scharnier 2-flüglig', 'Technikdeckel mit Scharnier, zweiflüglig');
select pg_temp.r('Holzdeck', 'Deckel ca. 1mx1m', 'Technikdeckel ohne Scharnier', 'Ohne Scharnier', 'Technikdeckel ohne Scharnier');
select pg_temp.r('Holzdeck', 'Deckel ca. 1mx1m', 'Minideckel für Skimmer usw.', 'Minideckel', 'Minideckel für Skimmer usw.');
select pg_temp.r('Holzdeck', '2 Stufen (2 Steigungen, 1 Stufe)', 'Accoya Grau', 'Accoya grau');
select pg_temp.r('Holzdeck', '2 Stufen (2 Steigungen, 1 Stufe)', 'Thermo-Kiefer', 'Thermokiefer');
select pg_temp.r('Holzdeck', 'Sitzelement oben und eine Seite verkleidet', 'Douglas', 'Douglasie');

-- Mauern
select pg_temp.r('Mauern', 'Transport Natursteine', 'Lieferwagen ab Lager', 'LW ab Lager', 'Lieferwagen ab Lager');
select pg_temp.r('Mauern', 'Hinterfüllung Kies', 'Kies LKW, Maschine S', 'Maschine S', null, 'LKW');
select pg_temp.r('Mauern', 'Hinterfüllung Kies', 'Kies LKW, Maschine M', 'Maschine M', null, 'LKW');
select pg_temp.r('Mauern', 'Hinterfüllung Kies', 'Kies LKW, Maschine L', 'Maschine L', null, 'LKW');
select pg_temp.r('Mauern', 'Hinterfüllung Kies', 'Kies Lieferwagen, Maschine S', 'Lieferwagen, S', 'Kies mit Lieferwagen, Maschine S');
select pg_temp.r('Mauern', 'Hinterfüllung Sickerbeton', 'Sickerbeton LKW, Maschine S', 'Maschine S', null, 'LKW');
select pg_temp.r('Mauern', 'Hinterfüllung Sickerbeton', 'Sickerbeton LKW, Maschine M', 'Maschine M', null, 'LKW');
select pg_temp.r('Mauern', 'Hinterfüllung Sickerbeton', 'Sickerbeton LKW, Maschine L', 'Maschine L', null, 'LKW');
select pg_temp.r('Mauern', 'Betonmauer Coffra', 'Coffra gepumpt', 'Gepumpt');
select pg_temp.r('Mauern', 'Betonmauer Coffra', 'Coffra mit Lieferwagen', 'Lieferwagen');
select pg_temp.r('Mauern', 'Verblender Z-Elemente', 'Z-Elemente Rusted Grey', 'Rusted Grey');
select pg_temp.r('Mauern', 'Verblender Z-Elemente', 'Z-Elemente Rusted Brown', 'Rusted Brown');
select pg_temp.r('Mauern', 'Verblender Geopietra', 'Geopietra Toce', 'Toce');
select pg_temp.r('Mauern', 'Verblender Geopietra', 'Geopietra Cascata', 'Cascata');
select pg_temp.r('Mauern', 'Zusatzarbeiten Blendmauer', 'Abdeckplatte Piasentina', 'Abdeckung Piasentina');
select pg_temp.r('Mauern', 'Zusatzarbeiten Blendmauer', 'Geopietra Abdeckung', 'Abdeckung Geopietra');
select pg_temp.r('Mauern', 'Zusatzarbeiten Blendmauer', 'Stirnseite Cortenblech', 'Stirn Corten', 'Stirnseite Cortenblech');
select pg_temp.r('Mauern', 'Zusatzarbeiten Blendmauer', 'Stirnseite Blech Anthrazit', 'Stirn Anthrazit', 'Stirnseite Blech Anthrazit');
update auswahlfeld f set name = 'Zusatzarbeiten Verblendmauer' from teilschritt t, arbeitsschritt a, offertentyp ot
  where f.teilschritt_id = t.id and t.arbeitsschritt_id = a.id and a.offertentyp_id = ot.id and ot.name = 'Mauern' and f.name = 'Zusatzarbeiten Blendmauer';

-- Regenwassertank
select pg_temp.r('Regenwassertank', 'Wasserzapfsäule', 'Wasserzapfsäule montieren', 'Montieren');
select pg_temp.r('Regenwassertank', 'Kernbohrung mit Pressring', 'Kernbohrung mit Pressring', 'Kernbohrung', 'Kernbohrung mit Pressring');

-- Bewässerung
select pg_temp.r('Bewässerung', 'Grabarbeiten usw. inkl Material', 'Team Servicetechniker Std.', 'Servicetechniker Std', 'Team Servicetechniker');
select pg_temp.r('Bewässerung', 'Grabarbeiten usw. inkl Material', 'Team Vorarbeiter Std', 'Vorarbeiter Std', 'Team Vorarbeiter');
select pg_temp.r('Bewässerung', 'Kellermontage', 'Kernbohrung für 4 Zonen inkl Presrring', 'Kernbohrung 4 Zonen', 'Kernbohrung für 4 Zonen, inkl. Pressring');
select pg_temp.r('Bewässerung', 'Installation Mapress Leitungen', 'Rohrleitungen 15mm', 'Rohrleitung 15 mm');
select pg_temp.r('Bewässerung', 'Installation Mapress Leitungen', 'Rohrleitungen 22mm', 'Rohrleitung 22 mm');
select pg_temp.r('Bewässerung', 'Installation Mapress Leitungen', 'Winkel, Übergänge 15mm', 'Winkel/Überg. 15 mm', 'Winkel, Übergänge 15 mm');
select pg_temp.r('Bewässerung', 'Installation Mapress Leitungen', 'Winkel, Übergänge 22mm', 'Winkel/Überg. 22 mm', 'Winkel, Übergänge 22 mm');

-- Boxen (Bewässerung und Gartenbeleuchtung)
do $$ declare t text; begin
  foreach t in array array['Bewässerung', 'Gartenbeleuchtung'] loop
    perform pg_temp.r(t, 'Boxen', 'Wandbox S grau (2 Z)', 'S grau (2 Z)', 'Wandbox');
    perform pg_temp.r(t, 'Boxen', 'Wandbox S anthrazit (2 Z)', 'S anthrazit (2 Z)', 'Wandbox');
    perform pg_temp.r(t, 'Boxen', 'Wandbox M grau (4 Z)', 'M grau (4 Z)', 'Wandbox');
    perform pg_temp.r(t, 'Boxen', 'Wandbox M anthrazit (4 Z)', 'M anthrazit (4 Z)', 'Wandbox');
    perform pg_temp.r(t, 'Boxen', 'Wandbox L grau', 'L grau', 'Wandbox');
    perform pg_temp.r(t, 'Boxen', 'Wandbox L anthrazit', 'L anthrazit', 'Wandbox');
  end loop;
end $$;

-- Gartenbeleuchtung
select pg_temp.r('Gartenbeleuchtung', 'Vorarbeiten Grabarbeiten', 'Vorarbeiten, Grabarbeiten', 'Grabarbeiten', 'Vorarbeiten, Grabarbeiten');
select pg_temp.r('Gartenbeleuchtung', 'Vorarbeiten Grabarbeiten', 'Leerohre M25 verlegen', 'Leerrohr M25', 'Leerrohr M25 verlegen');
select pg_temp.r('Gartenbeleuchtung', 'Vorarbeiten Grabarbeiten', 'Leerohre M32 verlegen', 'Leerrohr M32', 'Leerrohr M32 verlegen');
select pg_temp.r('Gartenbeleuchtung', 'Vorarbeiten Grabarbeiten', 'Leerohre M50 verlegen', 'Leerrohr M50', 'Leerrohr M50 verlegen');
select pg_temp.r('Gartenbeleuchtung', 'Netzteil', 'Netzteil Normal', 'Normal');
select pg_temp.r('Gartenbeleuchtung', 'Netzteil', 'Netzteil Dali Dimmer', 'Dali Dimmer', 'Netzteil Dali Dimmer');
select pg_temp.r('Gartenbeleuchtung', 'Netzteil', 'Steuerung Ein/Aus Mono', 'Ein/Aus Mono', 'Steuerung Ein/Aus Mono');
select pg_temp.r('Gartenbeleuchtung', 'Netzteil', 'Steuerung Ein/Aus RGBW', 'Ein/Aus RGBW', 'Steuerung Ein/Aus RGBW');
select pg_temp.r('Gartenbeleuchtung', 'Netzteil', 'Steuerung Dali', 'Dali-Steuerung');
select pg_temp.r('Gartenbeleuchtung', 'LED Band', 'LED Band Leuchtmittel', 'Leuchtmittel', 'LED-Band Leuchtmittel');

-- Naturteich/Schwimmteich
select pg_temp.r('Naturteich/Schwimmteich', 'Bodenplatte', 'Bodenplatte gepumpt', 'Gepumpt');
select pg_temp.r('Naturteich/Schwimmteich', 'Bodenplatte', 'Bodenplatte LKW', 'LKW');
select pg_temp.r('Naturteich/Schwimmteich', 'Bodenplatte', 'Bodenplatte Lieferwagen', 'Lieferwagen');
select pg_temp.r('Naturteich/Schwimmteich', 'Bodenplatte', 'Zusatz: Magerbeton-Schicht', '+ Magerbeton', 'Zusatz: Magerbeton-Schicht');
select pg_temp.r('Naturteich/Schwimmteich', 'Teichfolie', 'Teichfolie verlegen', 'Verlegen');
select pg_temp.r('Naturteich/Schwimmteich', 'Teichfolie', 'Zusatz: Eck-Ausbildung', '+ Eck-Ausbildung');
select pg_temp.r('Naturteich/Schwimmteich', 'Teichfolie', 'Zusatz: Durchbruch / Rohrmanschette', '+ Rohrmanschette', 'Zusatz: Durchbruch / Rohrmanschette');
select pg_temp.r('Naturteich/Schwimmteich', 'Teichfolie', 'Zusatz: Service-Techniker Contec', '+ Techniker Contec', 'Zusatz: Service-Techniker Contec');
select pg_temp.r('Naturteich/Schwimmteich', 'Kapillarsperre', 'Kapillarsperre Betonstellriemen Lieferwagen', 'Stellriemen LW', 'Betonstellriemen mit Lieferwagen');
select pg_temp.r('Naturteich/Schwimmteich', 'Kapillarsperre', 'Kapillarsperre Betonstellriemen LKW gepumpt', 'Stellriemen gepumpt', 'Betonstellriemen, LKW gepumpt');
select pg_temp.r('Naturteich/Schwimmteich', 'Kapillarsperre', 'Kapillarsperre Holzbretter', 'Holzbretter');
select pg_temp.r('Naturteich/Schwimmteich', 'Verrohrung Übergabepunkt-Technikstandort', 'Grabarbeiten Tageseinsatz', 'Grabarbeiten / Tag', 'Grabarbeiten im Tageseinsatz. Anzahl = Tage.');
select pg_temp.r('Naturteich/Schwimmteich', 'Umwälzpumpe', 'Kobre Tec 20`000 12V', '20''000 12V', 'Kobre Tec 20''000, 12 V.' || E'\n' || 'Getauchte Pumpe für Becken, in denen gebadet wird (Bio).');

-- Pooloptionen
select pg_temp.r('Pooloptionen', 'Wärmepumpe', 'Zusatz: isolierte Leitungen pro/ml', '+ Isol. Leitung /m', 'Zusatz: isolierte Leitungen, pro Laufmeter');
select pg_temp.r('Pooloptionen', 'Wärmepumpe', 'Zusatz: Fundament Wärmepumpe', '+ Fundament', 'Zusatz: Fundament Wärmepumpe');
select pg_temp.r('Pooloptionen', 'Wärmepumpe', 'Zusatz: Wandmontage Wärmepumpe', '+ Wandmontage', 'Zusatz: Wandmontage Wärmepumpe');
select pg_temp.r('Pooloptionen', 'Wärmepumpe', 'Zusatz: Kernbohrung mit Pressring', '+ Kernbohrung', 'Zusatz: Kernbohrung mit Pressring');
select pg_temp.r('Pooloptionen', 'Wärmetauscher', 'Plattenw. 20m3', '20 m³', 'Plattenwärmetauscher 20 m³', 'Plattenwärmetauscher');
select pg_temp.r('Pooloptionen', 'Wärmetauscher', 'Plattenw. 40m3', '40 m³', 'Plattenwärmetauscher 40 m³', 'Plattenwärmetauscher');
select pg_temp.r('Pooloptionen', 'Wärmetauscher', 'Plattenw. 70m3', '70 m³', 'Plattenwärmetauscher 70 m³', 'Plattenwärmetauscher');
select pg_temp.r('Pooloptionen', 'Wärmetauscher', 'Plattenw. 90 m3', '90 m³', 'Plattenwärmetauscher 90 m³', 'Plattenwärmetauscher');
select pg_temp.r('Pooloptionen', 'Gegenstromanlage', 'EVA 175 Control Eco', '175 Control Eco', null, 'EVA');
select pg_temp.r('Pooloptionen', 'Gegenstromanlage', 'EVA 225 Control 1', '225 Control 1', null, 'EVA');
select pg_temp.r('Pooloptionen', 'Gegenstromanlage', 'EVA 225 Control 2', '225 Control 2', null, 'EVA');
select pg_temp.r('Pooloptionen', 'Gegenstromanlage', 'EVA 275 Control 1', '275 Control 1', null, 'EVA');
select pg_temp.r('Pooloptionen', 'Gegenstromanlage', 'EVA 275 Control 2', '275 Control 2', null, 'EVA');
select pg_temp.r('Pooloptionen', 'Poolboden', 'Boden auf PP Becken m2', 'PP-Becken (m²)', 'Boden auf PP-Becken, Menge in m²');
select pg_temp.r('Pooloptionen', 'Poolboden', 'Boden auf Beton/Folie m2', 'Beton/Folie (m²)', 'Boden auf Beton/Folie, Menge in m²');
select pg_temp.r('Pooloptionen', 'Poolboden', 'Laufmeter Sitzbank, Treppe usw. bekleben', 'Sitzbank/Treppe (m)', 'Sitzbank, Treppe usw. bekleben, Menge in Laufmetern');
select pg_temp.r('Pooloptionen', 'Dusche', 'Norderney (Fussbrause)', 'Norderney', 'Fussbrause', 'Modell');
select pg_temp.r('Pooloptionen', 'Dusche', 'Sylt (Handbrause)', 'Sylt', 'Handbrause', 'Modell');
select pg_temp.r('Pooloptionen', 'Dusche', 'Juist (Handbrause)', 'Juist', 'Handbrause', 'Modell');
select pg_temp.r('Pooloptionen', 'Dusche', 'Zusatz: Fundament Dusche', '+ Fundament', 'Zusatz: Fundament Dusche');
select pg_temp.r('Pooloptionen', 'Dusche', 'Zusatz: Fundament mit Duschwanne', '+ Fundament Wanne', 'Zusatz: Fundament mit Duschwanne');
select pg_temp.r('Pooloptionen', 'Dusche', 'Zusatz: Abwasserleitung Dusche verlegen', '+ Abwasserleitung', 'Zusatz: Abwasserleitung Dusche verlegen');
select pg_temp.r('Pooloptionen', 'Poolroboter', 'Dolphin EON 120d (Akku)', 'Dolphin EON 120d', 'Mit Akku', 'Roboter');
select pg_temp.r('Pooloptionen', 'Poolroboter', 'Dolphin S3000 (mit Kabel)', 'Dolphin S3000', 'Mit Kabel', 'Roboter');
select pg_temp.r('Pooloptionen', 'Poolroboter', 'Volt FX-8 Li (Akku-Handreiniger)', 'Volt FX-8 Li', 'Akku-Handreiniger', 'Roboter');

-- Bepflanzung, Rasen
select pg_temp.r('Bepflanzung', 'Arbeitszeit', 'Deponiegebühr div. Material m3', 'Deponie (m³)', 'Deponiegebühr div. Material, Menge in m³');
select pg_temp.r('Bepflanzung', 'Befüllung', 'Landerde (Humus ab Lager)', 'Landerde', 'Humus ab Lager');
select pg_temp.r('Bepflanzung', 'Befüllung', 'Substrat, Säcke à 30 l', 'Substrat Sack 30 l', 'Substrat, Säcke à 30 l');
select pg_temp.r('Rasen', 'Rollrasen verlegen', 'Allzweck-Rollrasen', 'Allzweck');
select pg_temp.r('Rasen', 'Rollrasen verlegen', 'Rollrasen Spezial', 'Spezial');
