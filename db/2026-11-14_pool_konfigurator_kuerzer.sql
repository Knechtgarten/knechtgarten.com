-- Pool/Wassergarten: Konfigurator-Knöpfe kürzer, L/M/S usw. als Optionsgruppen (ein Knopf mit Dropdown).
-- Nur Namen, Mouse-over-Texte, Reihenfolge und Gruppen – Rechnung unverändert.
-- Ausnahme Poolabdeckung: «Oberflur» = Gruppe Kunststoff + 5 Hölzer; jedes Holz enthält jetzt die Abdeckung selbst
-- (Zeilen der bisherigen Option «Abdeckung Oberflur Holzverkleidung», von der m²-Menge ausgenommen). Diese Option wird entfernt (in keiner Offerte verwendet).
do $$
declare
  g uuid;
  holz_basis uuid;
  af_abd constant uuid := 'fe3bf9d9-c005-4c60-a1cc-2a9bd7c78e46';
  w record;
begin
  create temp table po on commit drop as
    select o.id, o.name from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id
    join arbeitsschritt a on a.id = t.arbeitsschritt_id join offertentyp ot on ot.id = a.offertentyp_id
    where ot.name ilike 'Pool/Wasser%';

  -- Aushub: Baumaschinen L/M/S und Kranaushub als Gruppen
  g := gen_random_uuid();
  update auswahloption set optionsgruppe_id = g, optionsgruppe_name = 'Baumaschinen', name = right(name, 1)
    where id in (select id from po where name in ('Baumaschinen L', 'Baumaschinen M', 'Baumaschinen S'));
  g := gen_random_uuid();
  update auswahloption set optionsgruppe_id = g, optionsgruppe_name = 'Kranaushub',
    name = 'bis ' || regexp_replace(name, '^Kranaushub -(\d+)m$', '\1') || ' m'
    where id in (select id from po where name in ('Kranaushub -20m', 'Kranaushub -30m', 'Kranaushub -45m'));
  update auswahloption set name = 'Mulde LKW' where id in (select id from po where name = 'Abtransport Mulde LKW');
  update auswahloption set name = 'Lieferwagen' where id in (select id from po where name = 'Abtransport Lieferwagen');

  -- Betonfundament
  update auswahloption set name = 'Splittbeton' where id in (select id from po where name = 'Betonfundament Splittbeton');
  update auswahloption set name = 'Zusatz Überlaufpool' where id in (select id from po where name = 'Zusatzaufwand Überlaufpool');

  -- Beckeneinbau 15/20/27/31/45 m als Gruppe
  g := gen_random_uuid();
  update auswahloption set optionsgruppe_id = g, optionsgruppe_name = 'Beckeneinbau',
    name = regexp_replace(name, '^Beckeneinbau (\d+)m$', '\1 m')
    where id in (select id from po where name ~ '^Beckeneinbau \d+m$');

  -- Betonkragen
  update auswahloption set name = 'Kragen LW' where id in (select id from po where name = 'Betonkragen LW');
  update auswahloption set name = 'Kragen gepumpt' where id in (select id from po where name = 'Betonkragen LKW gepumpt');

  -- Verrohrung
  update auswahloption set name = 'Grabarbeiten / Tag', hinweistext = 'Grabarbeiten im Tageseinsatz. Anzahl = Tage.'
    where id in (select id from po where name = 'Grabarbeiten Tageseinsatz');
  update auswahloption set name = '2-4 Leitungen Bio', hinweistext = 'Geberit-Rohre.' || E'\n' || 'Pro Laufmeter Leitungspaket.' || E'\n' || 'Ohne Grabarbeiten. Nur Materiallieferung und Verrohrungsaufwand.'
    where id in (select id from po where name = '2-4 Leitungen Bio Geberit');

  -- Umwälzpumpe
  update auswahloption set hinweistext = 'Wassergekühltes Topmodell für chemische Pools und Vliesfilter.'
    where id in (select id from po where name = 'Inv. Master 30');
  update auswahloption set hinweistext = 'Budgetmodell für chemische Pools. 14.5 m³/h.'
    where id in (select id from po where name = 'Inv. Captain');
  update auswahloption set name = 'Pumpe Badebr.', hinweistext = 'Pumpe für Badebrunnen und Zierbecken. 14.5 m³/h.'
    where id in (select id from po where name = 'Pumpe Badebrunnen');
  update auswahloption set name = '20''000 12V', hinweistext = 'Kobre Tec 20''000, 12 V.' || E'\n' || 'Getauchte Pumpe für Becken, in denen gebadet wird (Bio).'
    where id in (select id from po where name like 'Kobre Tec 20%12V');

  -- Wasseraufbereitung Bio, Filtration
  update auswahloption set name = 'Füllung Classic' where id in (select id from po where name = 'Biofilterfüllung Classic');
  update auswahloption set name = 'Füllung Helix' where id in (select id from po where name = 'Biofilterfüllung Helix');
  update auswahloption set name = 'Badebrunnen' where id in (select id from po where name = 'Kartusche Badebrunnen');

  -- Schränke, Techniklokal
  update auswahloption set name = 'Schrank L besch.' where id in (select id from po where name = 'Schrank L beschichtet');
  update auswahloption set name = 'Box besch.' where id in (select id from po where name = 'Box beschichtet');
  g := gen_random_uuid();
  update auswahloption set optionsgruppe_id = g, optionsgruppe_name = 'Schacht', name = right(name, 1)
    where id in (select id from po where name in ('Schacht L', 'Schacht M', 'Schacht S'));
  update auswahloption set name = 'Technikdeckel' where id in (select id from po where name = 'Deckel zu Technikschacht');
  update auswahloption set name = 'Kellermontage', hinweistext = 'Verbindungsleitungen im Keller montieren. Inkl. Pressringe, ohne Kernbohrung.'
    where id in (select id from po where name = 'Kellermontage inkl. Pressringe');

  -- Skimmer
  update auswahloption set name = 'Miniskimmer', hinweistext = 'Für Minibecken. Nur Lieferung, exkl. Montage.'
    where id in (select id from po where name = 'Miniskimmer exkl. Mont.');

  -- Poolabdeckung
  update auswahloption set name = 'PP-Becken' where id in (select id from po where name = 'Abdeckung PP-Becken');
  update auswahloption set name = 'Unterflur inkl. Bank' where id in (select id from po where name = 'Abdeckung Unterflur inkl. Sitzbank');
  update auswahloption set name = 'Unterflur exkl. Bank' where id in (select id from po where name = 'Abdeckung Unterflur exkl. Sitzbank');

  select id into holz_basis from auswahloption where auswahlfeld_id = af_abd and name = 'Abdeckung Oberflur Holzverkleidung';
  if holz_basis is null then raise exception 'Option «Abdeckung Oberflur Holzverkleidung» nicht gefunden.'; end if;
  if exists (select 1 from offerte_auswahl where option_id = holz_basis) then raise exception 'Holzverkleidung wird in Offerten verwendet – abgebrochen.'; end if;

  g := gen_random_uuid();
  update auswahloption set name = 'Kunststoff', optionsgruppe_id = g, optionsgruppe_name = 'Oberflur', reihenfolge = 4
    where auswahlfeld_id = af_abd and name = 'Abdeckung Oberflur inkl. Verkleidung';
  for w in select id, name, reihenfolge from auswahloption where auswahlfeld_id = af_abd and optionsgruppe_name = 'Holzverkleidung' order by reihenfolge loop
    insert into ressourcenzeile select (jsonb_populate_record(null::ressourcenzeile,
      to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', w.id, 'mengenoption_ausgenommen', true, 'reihenfolge', coalesce(r.reihenfolge, 0) + 10))).*
      from ressourcenzeile r where r.option_id = holz_basis;
    update auswahloption set mehrfachauswahl = false, optionsgruppe_id = g, optionsgruppe_name = 'Oberflur', reihenfolge = w.reihenfolge - 1,
      hinweistext = 'Oberflur-Abdeckung mit Holzverkleidung ' || w.name || '.' || E'\n' || 'Menge = m² Verkleidung.'
      where id = w.id;
  end loop;
  delete from auswahloption where id = holz_basis;
end $$;
