-- ============================================================================
-- Wissen & Geräte: Startbestand aus dem Google Sheet «Fahrzeugliste und Maschinen 2026»
-- (Blätter Instandhaltungsplan LW/PW 2026, Baumaschinen, Maschinen Pflege).
-- Fahrzeuge/Maschinen, die schon im Einsatzplaner sind, werden damit verknüpft.
-- Fremdfahrzeuge und Telefonnummern werden bewusst nicht übernommen.
-- Läuft nur, solange wissen_eintrag noch leer ist.
-- ============================================================================

-- Hilfsfunktionen nur für diesen Import
create or replace function pg_temp.kv(variadic t text[])
returns jsonb language plpgsql as $$
declare r jsonb := '[]'; i int := 1;
begin
  while i < coalesce(array_length(t, 1), 0) loop
    if t[i+1] is not null and t[i+1] <> '' then
      r := r || jsonb_build_array(jsonb_build_object('label', t[i], 'wert', t[i+1]));
    end if;
    i := i + 2;
  end loop;
  return r;
end; $$;

create or replace function pg_temp.imp(
  p_titel text, p_unter text, p_nr text, p_kat text, p_ber text[], p_art text, p_zust text,
  p_steck jsonb, p_verw jsonb, p_tags text[], p_planer text, p_notiz text)
returns uuid language plpgsql as $$
declare v_id uuid; v_planer uuid;
begin
  if p_planer is not null then
    select id into v_planer from planer_ressource where name = p_planer or nummer = p_planer order by (name = p_planer) desc limit 1;
  end if;
  insert into wissen_eintrag (typ, titel, untertitel, nummer, kategorie_id, bereich_ids, geraeteart, zustaendig, steckbrief, verwaltung, tags, planer_ressource_id)
  values ('geraet', p_titel, p_unter, p_nr,
          (select id from wissen_kategorie where name = p_kat),
          coalesce((select array_agg(id) from wissen_bereich where name = any(p_ber)), '{}'),
          p_art, p_zust, coalesce(p_steck, '[]'), coalesce(p_verw, '[]'), coalesce(p_tags, '{}'), v_planer)
  returning id into v_id;
  if p_notiz is not null then
    insert into wissen_notiz (eintrag_id, html) values (v_id, '<p>' || p_notiz || '</p>');
  end if;
  return v_id;
end; $$;

do $$
declare
  mf constant text := 'Maschinen & Fahrzeuge';
  gw constant text := 'Geräte & Werkzeug';
  bau constant text[] := array['Baustelle', 'Werkstatt & Fuhrpark'];
  fp constant text[] := array['Werkstatt & Fuhrpark'];
  pfl constant text[] := array['Pflege'];
  aus constant text := 'Aus dem Instandhaltungsplan (Sheet): ';
  t int; teams text[] := array['Team 1 Conä', 'Team 2 Samir', 'Team 3 Selina', 'Team 4'];
begin
  if exists (select 1 from wissen_eintrag) then
    raise notice 'wissen_eintrag ist nicht leer - Import übersprungen';
    return;
  end if;

  -- ---------------- Raupenbagger ----------------
  perform pg_temp.imp('Raupenbagger 2.1', 'Takeuchi TB219 · 2 t', '2.1', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB219','Gewicht','2 t','Min. Durchfahrtsbreite','1.00 m','Anschaffungsjahr','2010','Betriebsstunden Nov. 2024','1887 h','Betriebsstunden Nov. 2025','2005 h'),
    null, array['Takeuchi'], 'Bagger 2.1', aus || 'kein Service 2024.');
  perform pg_temp.imp('Raupenbagger 2.2', 'Takeuchi TB219 · 2 t', '2.2', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB219','Gewicht','2 t','Anschaffungsjahr','2011','Betriebsstunden Nov. 2024','1936 h','Betriebsstunden Nov. 2025','2063 h'),
    null, array['Takeuchi'], 'Bagger 2.2', aus || 'kein Service 2024.');
  perform pg_temp.imp('Raupenbagger 2.3', 'Takeuchi TB219 · 2 t', '2.3', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB219','Gewicht','2 t','Anschaffungsjahr','2021','Betriebsstunden Nov. 2024','565 h','Betriebsstunden Nov. 2025','709 h'),
    null, array['Takeuchi'], 'Bagger 2.3', aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Raupenbagger 3.1', 'Takeuchi TB228 · 3.5 t', '3.1', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB228','Gewicht','3.5 t','Anschaffungsjahr','2012','Betriebsstunden Nov. 2024','1584 h','Betriebsstunden Nov. 2025','1692 h'),
    null, array['Takeuchi'], 'Bagger 3.1', aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Raupenbagger 3.2', 'Takeuchi TB228 · 3.5 t', '3.2', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB228','Gewicht','3.5 t','Anschaffungsjahr','2011','Betriebsstunden Nov. 2024','1804 h','Betriebsstunden Nov. 2025','1933 h'),
    null, array['Takeuchi'], 'Bagger 3.2', aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Raupenbagger 9.1', 'Takeuchi TB290 · 9 t', '9.1', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB290','Gewicht','9 t','Min. Durchfahrtsbreite','2.25 m','Anschaffungsjahr','2014','Betriebsstunden Nov. 2024','2433 h','Betriebsstunden Nov. 2025','2502 h'),
    null, array['Takeuchi'], 'Bagger 9.1', aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Raupenbagger 9.2', 'Takeuchi TB290 · 9 t', '9.2', mf, bau, 'Raupenbagger', null,
    pg_temp.kv('Hersteller / Modell','Takeuchi TB290','Gewicht','9 t','Min. Durchfahrtsbreite','2.25 m','Anschaffungsjahr','2019','Betriebsstunden Nov. 2024','874 h','Betriebsstunden Nov. 2025','913.5 h'),
    null, array['Takeuchi'], 'Bagger 9.2', aus || 'kein Service 2024.');

  -- ---------------- Anbaugeräte ----------------
  perform pg_temp.imp('Greifer 9 t', 'Martin', null, mf, array['Baustelle'], 'Anbaugerät', null, pg_temp.kv('Hersteller','Martin','Passt an','Bagger 9 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Spitzhammer 9 t', 'Martin HAP M10 TKB101-401', null, mf, array['Baustelle'], 'Anbaugerät', null,
    pg_temp.kv('Hersteller / Modell','Martin HAP M10 TKB101-401','Baujahr','2021','Anschaffungsjahr','2023','Passt an','Bagger 9 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Stielverlängerung 9 t', 'Martin STV M10/M18 3200 Hydr.', null, mf, array['Baustelle'], 'Anbaugerät', null,
    pg_temp.kv('Hersteller / Modell','Martin STV M10/M18 3200 Hydr.','Baujahr','2020','Passt an','Bagger 9 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Greifer 3.5 t (1)', 'Martin', null, mf, array['Baustelle'], 'Anbaugerät', null, pg_temp.kv('Hersteller','Martin','Passt an','Bagger 3.5 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Greifer 3.5 t (2)', 'Martin', null, mf, array['Baustelle'], 'Anbaugerät', null, pg_temp.kv('Hersteller','Martin','Passt an','Bagger 3.5 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Greifer 2 t (1)', 'Martin', null, mf, array['Baustelle'], 'Anbaugerät', null, pg_temp.kv('Hersteller','Martin','Passt an','Bagger 2 t'), null, array['Anbaugerät'], null, null);
  perform pg_temp.imp('Greifer 2 t (2)', 'Martin', null, mf, array['Baustelle'], 'Anbaugerät', null, pg_temp.kv('Hersteller','Martin','Passt an','Bagger 2 t'), null, array['Anbaugerät'], null, null);

  -- ---------------- Dumper, Lader ----------------
  perform pg_temp.imp('Raupendumper gross R.1', 'Rufener RK085 DM', 'R.1', mf, bau, 'Raupendumper', null,
    pg_temp.kv('Hersteller / Modell','Rufener RK085 DM','Min. Durchfahrtsbreite','1.20 m','Nutzlast','2 t','Leergewicht','1.44 t','Anschaffungsjahr','2015','Betriebsstunden Nov. 2024','290 h','Betriebsstunden Nov. 2025','314 h'),
    null, array['Rufener'], 'Raupendumper gross R.1', aus || 'Service 2024 gemacht. Im Juli 2024 zwei neue Raupen.');
  perform pg_temp.imp('Raupendumper gross R.7', 'Rufener RK085 DM', 'R.7', mf, bau, 'Raupendumper', null,
    pg_temp.kv('Hersteller / Modell','Rufener RK085 DM','Anschaffungsjahr','2026'), null, array['Rufener'], 'Raupendumper gross R.7', null);
  perform pg_temp.imp('Raupendumper R.3', 'Rufener RK049 DM S (93)', 'R.3', mf, bau, 'Raupendumper', null,
    pg_temp.kv('Hersteller / Modell','Rufener RK049 DM S (93)','Min. Durchfahrtsbreite','0.98 m','Anschaffungsjahr','2019','Betriebsstunden Nov. 2024','266 h','Betriebsstunden Nov. 2025','308 h'),
    null, array['Rufener'], 'Raupendumper R.3', aus || 'kein Service 2024. Im März 2024 neue Raupe beidseitig.');
  perform pg_temp.imp('Raupendumper R.4', 'Rufener RK049 DM S (94)', 'R.4', mf, bau, 'Raupendumper', null,
    pg_temp.kv('Hersteller / Modell','Rufener RK049 DM S (94)','Min. Durchfahrtsbreite','0.98 m','Nutzlast','1 t','Leergewicht','815 kg','Anschaffungsjahr','2019','Betriebsstunden Nov. 2024','192 h'),
    null, array['Rufener'], 'Raupendumper R.4', aus || 'kein Service 2024, Service 2025 gemacht.');
  perform pg_temp.imp('Raupendumper klein R.2', 'Rufener RK 037/0823371(53)', 'R.2', mf, bau, 'Raupendumper', null,
    pg_temp.kv('Hersteller / Modell','Rufener RK 037/0823371(53)','Min. Durchfahrtsbreite','0.88 m','Nutzlast','800 kg','Leergewicht','630 kg','Anschaffungsjahr','2024','Betriebsstunden Nov. 2024','5 h','Betriebsstunden Nov. 2025','54 h'),
    null, array['Rufener'], 'Raupendumper klein R.2', aus || 'kein Service 2024.');
  perform pg_temp.imp('Dumper gross (Radtumper)', 'Typ DW 50', 'BE-866256', mf, bau, 'Dumper', null,
    pg_temp.kv('Typ','DW 50','Kontrollschild','BE-866256','Min. Durchfahrtsbreite','1.95 m','Anschaffungsjahr','2017','Betriebsstunden Okt. 2025','456 h','Fahrzeugprüfung','vorgeführt März 2024'),
    pg_temp.kv('Versicherung / LSVA','CHF 150 pro Monat'), null, 'Radtumper gross', aus || 'Juli 2023 / nur mit Nummernschild.');
  perform pg_temp.imp('Pneulader Kramer', 'Kramer', 'BE-6584', mf, bau, 'Lader', null,
    pg_temp.kv('Hersteller','Kramer','Kontrollschild','BE-6584','Anschaffungsjahr','2006','Betriebsstunden','2378 h'), null, array['Kramer'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Raupenlader Vermeer', 'Vermeer', null, mf, bau, 'Lader', null, pg_temp.kv('Hersteller','Vermeer'), null, array['Vermeer'], null, aus || 'kein Service 2024.');
  perform pg_temp.imp('Elektrostapler (Ameise)', 'Linde L12l', null, mf, fp, 'Stapler', null,
    pg_temp.kv('Hersteller / Modell','Linde L12l','Baujahr','2015','Anschaffungsjahr','2022'), null, array['Linde'], null, aus || 'kein Service 2024.');

  -- ---------------- Verdichtung, Fräsen ----------------
  perform pg_temp.imp('Grabenstampfer 1', 'Wacker BS 50-211 · 60 kg', '1', gw, array['Baustelle'], 'Grabenstampfer', 'Reto',
    pg_temp.kv('Hersteller / Modell','Wacker BS 50-211','Gewicht','60 kg','Anschaffungsjahr','2021'), pg_temp.kv('Kaufpreis','CHF 2''300'), array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Grabenstampfer 2', 'Wacker · 60 kg', '2', gw, array['Baustelle'], 'Grabenstampfer', 'Noé',
    pg_temp.kv('Hersteller','Wacker','Gewicht','60 kg','Anschaffungsjahr','2021'), null, array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Grabenstampfer 3', 'Wacker', '3', gw, array['Baustelle'], 'Grabenstampfer', 'Marco',
    pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Grabenstampfer 4', 'Wacker BS 50-211 · 60 kg', '4', gw, array['Baustelle'], 'Grabenstampfer', 'Jenny',
    pg_temp.kv('Hersteller / Modell','Wacker BS 50-211','Gewicht','60 kg','Anschaffungsjahr','2021'), pg_temp.kv('Kaufpreis','CHF 2''300'), array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Grabenstampfer 5', 'Wacker', '5', gw, array['Baustelle'], 'Grabenstampfer', 'Dominic',
    pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Vibroplatte klein 1', 'Wacker WP 1540Aw · 90 kg', '1', gw, array['Baustelle'], 'Vibroplatte', 'Reto',
    pg_temp.kv('Hersteller / Modell','Wacker WP 1540Aw','Gewicht','90 kg','Anschaffungsjahr','2021'), pg_temp.kv('Kaufpreis','CHF 2''300'), array['Wacker'], null, null);
  perform pg_temp.imp('Vibroplatte 2', 'Wacker', '2', gw, array['Baustelle'], 'Vibroplatte', 'Noé', pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Vibroplatte 3', 'Wacker', '3', gw, array['Baustelle'], 'Vibroplatte', 'Marco', pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Vibroplatte 4', 'Wacker', '4', gw, array['Baustelle'], 'Vibroplatte', 'Jenny', pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Vibroplatte 5', 'Wacker', '5', gw, array['Baustelle'], 'Vibroplatte', 'Dominic', pg_temp.kv('Hersteller','Wacker'), null, array['Wacker'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Vibroplatte gross', 'Wacker DPU6555', null, gw, array['Baustelle'], 'Vibroplatte', null, pg_temp.kv('Hersteller / Modell','Wacker DPU6555'), null, array['Wacker'], null, aus || 'Service 2024 gemacht.');
  perform pg_temp.imp('Vibroplatte mittel', 'Wacker DPU 2950 Y', null, gw, array['Baustelle'], 'Vibroplatte', null, pg_temp.kv('Hersteller / Modell','Wacker DPU 2950 Y'), null, array['Wacker'], null, aus || 'Service 2025 gemacht.');
  perform pg_temp.imp('Belagsfräse', 'Robin EY28', null, gw, array['Baustelle'], 'Fräse', null, pg_temp.kv('Hersteller / Modell','Robin EY28'), null, null, null, null);
  perform pg_temp.imp('Nassfräse mittel', 'Eigerdiamant', null, gw, array['Baustelle'], 'Fräse', null, pg_temp.kv('Hersteller','Eigerdiamant'), null, null, null, null);
  perform pg_temp.imp('Nassfräse gross', 'Fuhrer Bachmann', null, gw, array['Baustelle'], 'Fräse', null, pg_temp.kv('Hersteller','Fuhrer Bachmann'), null, null, null, null);
  perform pg_temp.imp('Nassfräse klein', null, null, gw, array['Baustelle'], 'Fräse', null, null, null, null, null, null);
  perform pg_temp.imp('Blatt Tischfräse Keramik', 'Eiger', null, gw, array['Baustelle'], 'Zubehör', null, pg_temp.kv('Hersteller','Eiger'), null, null, null, null);
  perform pg_temp.imp('Blatt Tischfräse', 'Typ 2050', null, gw, array['Baustelle'], 'Zubehör', null, pg_temp.kv('Typ','2050'), null, null, null, null);
  perform pg_temp.imp('Trennjäger-Blatt gross', 'Stihl / Eiger Typ 2020.350.20', null, gw, array['Baustelle'], 'Zubehör', null, pg_temp.kv('Typ','2020.350.20'), null, null, null, null);
  perform pg_temp.imp('Trennjäger-Blatt', 'Stihl / Eiger Typ 2020.300.20', null, gw, array['Baustelle'], 'Zubehör', null, pg_temp.kv('Typ','2020.300.20'), null, null, null, null);
  perform pg_temp.imp('Bodenfräse / Umkehrfräse', 'Rapid', null, gw, array['Baustelle', 'Pflege'], 'Bodenfräse', null, pg_temp.kv('Hersteller','Rapid'), null, null, null, null);
  perform pg_temp.imp('Bodenfräse Agria', 'Agria 3600', null, gw, array['Baustelle', 'Pflege'], 'Bodenfräse', null, pg_temp.kv('Hersteller / Modell','Agria 3600'), null, null, null, null);
  perform pg_temp.imp('Bodenhacke Agria', 'Agria', null, gw, array['Baustelle', 'Pflege'], 'Bodenfräse', null, pg_temp.kv('Hersteller','Agria'), null, null, null, null);

  -- ---------------- Lieferwagen, Service-Bus ----------------
  perform pg_temp.imp('Lieferwagen BE-846047', 'Mitsubishi Fuso Pflege · Andrea', 'BE-846047', mf, array['Pflege', 'Werkstatt & Fuhrpark'], 'Lieferwagen', 'Andrea',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-846047','Stammfahrer','Andrea','Anschaffungsjahr','2025','Fahrzeugprüfung','Juli 2025','km Januar 2026','536'),
    pg_temp.kv('Kaskoschutz','voll','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-846047', null);
  perform pg_temp.imp('Lieferwagen BE-424586', 'Mitsubishi Fuso Pflege · Cornelia', 'BE-424586', mf, array['Pflege', 'Werkstatt & Fuhrpark'], 'Lieferwagen', 'Cornelia',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-424586','Stammfahrer','Cornelia','Anschaffungsjahr','2018','km Januar 2025','87''227','km Januar 2026','95''501'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-424586', null);
  perform pg_temp.imp('Lieferwagen BE-555732', 'Mitsubishi Fuso Pflege · Selina', 'BE-555732', mf, array['Pflege', 'Werkstatt & Fuhrpark'], 'Lieferwagen', 'Selina',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-555732','Stammfahrer','Selina','Anschaffungsjahr','2018','km Januar 2025','63''924','km Januar 2026','71''490'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-555732', null);
  perform pg_temp.imp('Lieferwagen BE-848254', 'Mitsubishi Fuso Pflege · Samir', 'BE-848254', mf, array['Pflege', 'Werkstatt & Fuhrpark'], 'Lieferwagen', 'Samir',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-848254','Stammfahrer','Samir','Anschaffungsjahr','2019','km Januar 2025','63''360','km Januar 2026','71''995'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-848254', null);
  perform pg_temp.imp('Lieferwagen BE-464602', 'Mitsubishi Fuso · Dominic', 'BE-464602', mf, fp, 'Lieferwagen', 'Dominic',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-464602','Stammfahrer','Dominic','Anschaffungsjahr','2017','Fahrzeugprüfung','Nov. 2026','km Januar 2025','168''526','km Januar 2026','120''440'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-464602', null);
  perform pg_temp.imp('Lieferwagen BE-518853', 'Mitsubishi Fuso · Stefanie', 'BE-518853', mf, fp, 'Lieferwagen', 'Stefanie',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-518853','Stammfahrer','Stefanie','Anschaffungsjahr','2019','km Januar 2025','124''965'),
    pg_temp.kv('Kaskoschutz','keine','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-518853', null);
  perform pg_temp.imp('Lieferwagen BE-545313', 'Mitsubishi Fuso · Timo', 'BE-545313', mf, fp, 'Lieferwagen', 'Timo',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-545313','Stammfahrer','Timo','Anschaffungsjahr','2019','Fahrzeugprüfung','vorgeführt Jan. 2026','km Januar 2025','94''488','km Januar 2026','109''509'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-545313', null);
  perform pg_temp.imp('Lieferwagen BE-533628', 'Mitsubishi Fuso · Kai', 'BE-533628', mf, fp, 'Lieferwagen', 'Kai',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-533628','Stammfahrer','Kai','km Januar 2025','40''779','km Januar 2026','53''158'),
    pg_temp.kv('Kaskoschutz','teil','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-533628', null);
  perform pg_temp.imp('Lieferwagen BE-881138', 'Mitsubishi Fuso · Remo', 'BE-881138', mf, fp, 'Lieferwagen', 'Remo',
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-881138','Stammfahrer','Remo','Anschaffungsjahr','2022','km Januar 2025','30''684','km Januar 2026','41''057'),
    pg_temp.kv('Kaskoschutz','voll','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-881138', null);
  perform pg_temp.imp('Lieferwagen BE-896782', 'Mitsubishi Fuso · Reserve', 'BE-896782', mf, fp, 'Lieferwagen', null,
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso','Kontrollschild','BE-896782','Anschaffungsjahr','2026'),
    pg_temp.kv('Kaskoschutz','voll','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-896782', null);
  perform pg_temp.imp('Lieferwagen BE-814529', 'Mitsubishi Fuso schmal', 'BE-814529', mf, fp, 'Lieferwagen', null,
    pg_temp.kv('Marke / Modell','Mitsubishi Fuso (schmal)','Kontrollschild','BE-814529','Anschaffungsjahr','2026','Fahrzeugprüfung','März 2026'),
    pg_temp.kv('Kaskoschutz','voll','Selbstbehalt','CHF 500'), array['Mitsubishi Fuso'], 'BE-814529', null);
  perform pg_temp.imp('Service-Bus BE-759185', 'Fiat Talento · Marco', 'BE-759185', mf, array['Pflege', 'Poolbau & Wasser', 'Werkstatt & Fuhrpark'], 'Lieferwagen', 'Marco',
    pg_temp.kv('Marke / Modell','Fiat Talento','Kontrollschild','BE-759185','Stammfahrer','Marco','Anschaffungsjahr','2018','km Januar 2025','67''488','km Januar 2026','81''484'),
    pg_temp.kv('Kaskoschutz','teil'), array['Fiat'], 'BE-759185', aus || 'Hagelschaden angegeben.');
  perform pg_temp.imp('VW Caddy BE-668658', 'VW Caddy · Patrick', 'BE-668658', mf, fp, 'Lieferwagen', 'Patrick',
    pg_temp.kv('Marke / Modell','VW Caddy','Kontrollschild','BE-668658','Stammfahrer','Patrick','Anschaffungsjahr','2022','km Januar 2025','30''000','km Januar 2026','45''540'),
    pg_temp.kv('Kaskoschutz','voll'), array['VW'], 'BE-668658', null);

  -- ---------------- Personenwagen ----------------
  perform pg_temp.imp('Personenwagen BE-531762', 'Dacia Dokker · Robi', 'BE-531762', mf, fp, 'Personenwagen', 'Robi',
    pg_temp.kv('Marke / Modell','Dacia Dokker','Kontrollschild','BE-531762','Anschaffungsjahr','2019','Fahrzeugprüfung','Vorführung Okt. 2024','km Januar 2025','56''970','km Januar 2026','61''600'),
    pg_temp.kv('Kaskoschutz','keine'), array['Dacia'], null, null);
  perform pg_temp.imp('Personenwagen BE-354665', 'Dacia Dokker · Benu', 'BE-354665', mf, fp, 'Personenwagen', 'Benu',
    pg_temp.kv('Marke / Modell','Dacia Dokker','Kontrollschild','BE-354665','Anschaffungsjahr','2019','Fahrzeugprüfung','Vorführung Okt. 2024','km Januar 2025','61''540','km Januar 2026','74''678'),
    pg_temp.kv('Kaskoschutz','keine'), array['Dacia'], null, null);
  perform pg_temp.imp('Personenwagen BE-317792', 'Kia XCeed · Stefu', 'BE-317792', mf, fp, 'Personenwagen', 'Stefu',
    pg_temp.kv('Marke / Modell','Kia XCeed','Kontrollschild','BE-317792','Anschaffungsjahr','2025'), pg_temp.kv('Kaskoschutz','voll'), array['Kia'], null, null);
  perform pg_temp.imp('Personenwagen BE-711059', 'Kia Ceed · Fäbu', 'BE-711059', mf, fp, 'Personenwagen', 'Fäbu',
    pg_temp.kv('Marke / Modell','Kia Ceed','Kontrollschild','BE-711059','Anschaffungsjahr','2026','km Januar 2026','24''000'), pg_temp.kv('Kaskoschutz','voll'), array['Kia'], null, null);
  perform pg_temp.imp('Personenwagen BE-509769', 'Kia Ceed · Päscu', 'BE-509769', mf, fp, 'Personenwagen', 'Päscu',
    pg_temp.kv('Marke / Modell','Kia Ceed','Kontrollschild','BE-509769','Anschaffungsjahr','2026','Fahrzeugprüfung','geprüft 20.1.2026','km Januar 2026','27''701'), pg_temp.kv('Kaskoschutz','voll'), array['Kia'], null, null);

  -- ---------------- Anhänger ----------------
  perform pg_temp.imp('Transportanhänger BE-597017', 'Keller 5308 Fahrzeugbau', 'BE-597017', mf, bau, 'Anhänger', 'Allgemein',
    pg_temp.kv('Marke','Keller 5308 Fahrzeugbau','Kontrollschild','BE-597017','Anschaffungsjahr','2022','Bemerkung','100 km/h auf der Autobahn erlaubt'), null, null, 'BE-597017', null);
  perform pg_temp.imp('Baustellenanhänger BE-22307', 'Niederberger', 'BE-22307', mf, bau, 'Anhänger', 'Fabian',
    pg_temp.kv('Marke','Niederberger','Kontrollschild','BE-22307','Anschaffungsjahr','2012','Fahrzeugprüfung','Juli 2024'), null, null, 'BE-22307', null);
  perform pg_temp.imp('Baustellenanhänger BE-22309', 'Niederberger', 'BE-22309', mf, bau, 'Anhänger', 'Dominic',
    pg_temp.kv('Marke','Niederberger','Kontrollschild','BE-22309','Anschaffungsjahr','2012','Fahrzeugprüfung','Aug. 2024'), null, null, 'BE-22309', null);
  perform pg_temp.imp('Baustellenanhänger BE-24121', 'Niederberger', 'BE-24121', mf, bau, 'Anhänger', 'Kai',
    pg_temp.kv('Marke','Niederberger','Kontrollschild','BE-24121','Anschaffungsjahr','2005','Fahrzeugprüfung','Nov. 2024'), null, null, 'BE-24121', null);
  perform pg_temp.imp('Baustellenanhänger BE-22452', 'Niederberger', 'BE-22452', mf, bau, 'Anhänger', 'Timo',
    pg_temp.kv('Marke','Niederberger','Kontrollschild','BE-22452','Anschaffungsjahr','2018'), null, null, 'BE-22452', aus || 'Neuer KABA-Schliesszylinder August 2024.');
  perform pg_temp.imp('Baustellenanhänger BE-22506', 'Niederberger', 'BE-22506', mf, bau, 'Anhänger', 'Steffi',
    pg_temp.kv('Marke','Niederberger','Kontrollschild','BE-22506','Anschaffungsjahr','2020'), null, null, 'BE-22506', null);

  -- ---------------- Pflege-Geräte pro Team ----------------
  for t in 1..4 loop
    perform pg_temp.imp('Heckenschere T' || t || '.1', 'Stihl HSA 100 · ' || teams[t], 'T' || t || '.1', gw, pfl, 'Heckenschere', teams[t],
      pg_temp.kv('Hersteller / Modell','Stihl HSA 100','Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 425' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Heckenschere T' || t || '.2', 'Stihl HSA 100 · ' || teams[t], 'T' || t || '.2', gw, pfl, 'Heckenschere', teams[t],
      pg_temp.kv('Hersteller / Modell','Stihl HSA 100','Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 425' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Stabheckenschere T' || t || '.3', 'Stihl HLA 86 · ' || teams[t], 'T' || t || '.3', gw, pfl, 'Stabheckenschere', teams[t],
      pg_temp.kv('Hersteller / Modell','Stihl HLA 86','Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 630' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Laubbläser T' || t || '.4', 'Stihl BGA 86 · ' || teams[t], 'T' || t || '.4', gw, pfl, 'Laubbläser', teams[t],
      pg_temp.kv('Hersteller / Modell','Stihl BGA 86','Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 355' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Laubbläser T' || t || '.5', 'Stihl BGA 86 · ' || teams[t], 'T' || t || '.5', gw, pfl, 'Laubbläser', teams[t],
      pg_temp.kv('Hersteller / Modell','Stihl BGA 86','Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 355' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Motorsense T' || t || '.6', case when t = 4 then 'Stihl FS 131 · ' else '' end || teams[t], 'T' || t || '.6', gw, pfl, 'Motorsense', teams[t],
      pg_temp.kv('Hersteller / Modell',case when t = 4 then 'Stihl FS 131' end,'Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 830' end), array['Stihl'], null, null);
    perform pg_temp.imp('Motorsäge Akku T' || t || '.7', case when t = 4 then 'Stihl MSA 161 T · ' else '' end || teams[t], 'T' || t || '.7', gw, pfl, 'Motorsäge', teams[t],
      pg_temp.kv('Hersteller / Modell',case when t = 4 then 'Stihl MSA 161 T' end,'Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 550' end), array['Stihl','Akku'], null, null);
    perform pg_temp.imp('Motorsäge T' || t || '.8', case when t = 4 then 'Stihl MS 201 TC-M · ' else '' end || teams[t], 'T' || t || '.8', gw, pfl, 'Motorsäge', teams[t],
      pg_temp.kv('Hersteller / Modell',case when t = 4 then 'Stihl MS 201 TC-M' end,'Team',teams[t],'Anschaffungsjahr',case when t = 4 then '2025' end),
      pg_temp.kv('Kaufpreis',case when t = 4 then 'CHF 1''070' end), array['Stihl'], null, null);
  end loop;

  -- ---------------- Weitere Pflege-Geräte ----------------
  perform pg_temp.imp('Balkenmäher', null, null, gw, pfl, 'Balkenmäher', null, null, null, null, null, null);
  perform pg_temp.imp('Sondenschneider', 'UTV SC15', null, gw, pfl, 'Sondenschneider', null, pg_temp.kv('Hersteller / Modell','UTV SC15'), null, null, null, null);
  perform pg_temp.imp('Rasenmäher RMA 443', 'Stihl RMA 443', null, gw, pfl, 'Rasenmäher', null, pg_temp.kv('Hersteller / Modell','Stihl RMA 443'), null, array['Stihl','Akku'], null, null);
  perform pg_temp.imp('Rasenmäher RMA 444', 'Stihl RMA 444', null, gw, pfl, 'Rasenmäher', null, pg_temp.kv('Hersteller / Modell','Stihl RMA 444'), null, array['Stihl','Akku'], null, null);
  perform pg_temp.imp('Rasenmäher RMA 445', 'Stihl RMA 445', null, gw, pfl, 'Rasenmäher', null, pg_temp.kv('Hersteller / Modell','Stihl RMA 445'), null, array['Stihl','Akku'], null, null);
  perform pg_temp.imp('Vertikutierer 1', 'ELIET 50L', null, gw, pfl, 'Vertikutierer', null, pg_temp.kv('Hersteller / Modell','ELIET 50L'), null, array['ELIET'], null, null);
  perform pg_temp.imp('Vertikutierer 2', 'ELIET 50L', null, gw, pfl, 'Vertikutierer', null, pg_temp.kv('Hersteller / Modell','ELIET 50L'), null, array['ELIET'], null, null);
  perform pg_temp.imp('Aerifizierer', 'PL600', null, gw, pfl, 'Aerifizierer', null, pg_temp.kv('Modell','PL600'), null, null, null, null);
  perform pg_temp.imp('Stockfräse', 'Vermeer SC130', null, gw, pfl, 'Stockfräse', null, pg_temp.kv('Hersteller / Modell','Vermeer SC130'), null, array['Vermeer'], null, null);

  -- ---------------- Service-Standards pro Geräteart (Wochen setzt Stefan im Tool) ----------------
  insert into wissen_service (geraeteart, arbeit, wer, sortierung) values
    ('Raupenbagger', 'Jährlicher Service', 'Werkstatt', 10),
    ('Raupendumper', 'Jährlicher Service', 'Werkstatt', 20),
    ('Lieferwagen', 'Jährlicher Service', 'Garage', 30),
    ('Grabenstampfer', 'Jährlicher Service', null, 40),
    ('Vibroplatte', 'Jährlicher Service', null, 50),
    ('Heckenschere', 'Messer schärfen', null, 60),
    ('Stabheckenschere', 'Messer schärfen', null, 70);
end $$;
