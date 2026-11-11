-- Betonpumpe (Staffelgruppe 63e21f43-…): Preisliste Fahrmischerpumpe lückenlos, pro m³, mindestens 4 m³
--  * Abrechnung «Pro Einheit»: Menge (m³) × Stufenpreis statt Stufenpreis pauschal
--  * Stufen nach Preisliste: «X m³» gilt von X bis unter X+1 (Bruchteile → höherer Satz),
--    «ab 4 m³» ab 0 (Mindestmenge 4), danach Bereiche 31–40 … über 300
--  * VP = EP × 1.25 (20 % Marge), auf ganze Franken gerundet wie bisher
--  * Alle Betonpumpen-Zeilen in den Vorlagen: Mindestmenge 4 m³ (= Mindestbetrag 4 × 148.50 EP)
--  * Fehlende Artikel 21–29 m³, ab 30 m³ und Bereiche bis über 300 m³ neu (Lieferant wie Pum20)
do $$
declare
  sg constant uuid := '63e21f43-c68a-4ebd-82f4-50b8c0bbc722';
  vorlage record; s record; art uuid; nr int := 0;
begin
  select * into vorlage from artikel where artikelnummer_knecht = 'DAEBET_Pum20';
  if vorlage.id is null then raise exception 'Artikel DAEBET_Pum20 fehlt'; end if;

  delete from staffelstufe where staffelgruppe_id = sg;

  for s in select * from (values
      ('Pum4',   'Betonpumpen bis 4 Kubik',     148.50,   0::numeric,   5::numeric),
      ('Pum5',   'Betonpumpen bis 5 Kubik',     119.50,   5,   6), ('Pum6',  'Betonpumpen bis 6 Kubik',  100.00,  6,  7),
      ('Pum7',   'Betonpumpen bis 7 Kubik',      87.50,   7,   8), ('Pum8',  'Betonpumpen bis 8 Kubik',   79.50,  8,  9),
      ('Pum9',   'Betonpumpen bis 9 Kubik',      74.00,   9,  10), ('Pum10', 'Betonpumpen bis 10 Kubik',  70.50, 10, 11),
      ('Pum11',  'Betonpumpen bis 11 Kubik',     67.00,  11,  12), ('Pum12', 'Betonpumpen bis 12 Kubik',  64.00, 12, 13),
      ('Pum13',  'Betonpumpen bis 13 Kubik',     61.00,  13,  14), ('Pum14', 'Betonpumpen bis 14 Kubik',  59.00, 14, 15),
      ('Pum15',  'Betonpumpen bis 15 Kubik',     56.50,  15,  16), ('Pum16', 'Betonpumpen bis 16 Kubik',  54.00, 16, 17),
      ('Pum17',  'Betonpumpen bis 17 Kubik',     51.50,  17,  18), ('Pum18', 'Betonpumpen bis 18 Kubik',  49.00, 18, 19),
      ('Pum19',  'Betonpumpen bis 19 Kubik',     47.50,  19,  20), ('Pum20', 'Betonpumpen bis 20 Kubik',  46.00, 20, 21),
      ('Pum21',  'Betonpumpen 21 Kubik',         45.00,  21,  22), ('Pum22', 'Betonpumpen 22 Kubik',      43.50, 22, 23),
      ('Pum23',  'Betonpumpen 23 Kubik',         42.00,  23,  24), ('Pum24', 'Betonpumpen 24 Kubik',      40.50, 24, 25),
      ('Pum25',  'Betonpumpen 25 Kubik',         40.00,  25,  26), ('Pum26', 'Betonpumpen 26 Kubik',      39.50, 26, 27),
      ('Pum27',  'Betonpumpen 27 Kubik',         39.00,  27,  28), ('Pum28', 'Betonpumpen 28 Kubik',      38.50, 28, 29),
      ('Pum29',  'Betonpumpen 29 Kubik',         38.00,  29,  30), ('Pum30', 'Betonpumpen ab 30 Kubik',   37.50, 30, 31),
      ('Pum31-40',   'Betonpumpen 31–40 Kubik',   36.00,  31,  41), ('Pum41-50',  'Betonpumpen 41–50 Kubik',  35.50,  41,  51),
      ('Pum51-60',   'Betonpumpen 51–60 Kubik',   34.00,  51,  61), ('Pum61-70',  'Betonpumpen 61–70 Kubik',  32.50,  61,  71),
      ('Pum71-80',   'Betonpumpen 71–80 Kubik',   31.00,  71,  81), ('Pum81-90',  'Betonpumpen 81–90 Kubik',  29.50,  81,  91),
      ('Pum91-100',  'Betonpumpen 91–100 Kubik',  28.00,  91, 101), ('Pum101-130','Betonpumpen 101–130 Kubik', 27.00, 101, 131),
      ('Pum131-160', 'Betonpumpen 131–160 Kubik', 25.50, 131, 161), ('Pum161-200','Betonpumpen 161–200 Kubik', 24.00, 161, 201),
      ('Pum201-300', 'Betonpumpen 201–300 Kubik', 22.50, 201, 301), ('Pum300+',   'Betonpumpen über 300 Kubik', 21.50, 301, null)
    ) v(code, name, ep, von, bis)
  loop
    nr := nr + 1;
    select id into art from artikel where artikelnummer_knecht = 'DAEBET_' || s.code;
    if art is null then
      art := gen_random_uuid();
      insert into artikel select * from jsonb_populate_record(null::artikel, to_jsonb(vorlage) || jsonb_build_object(
        'id', art, 'artikelnummer_knecht', 'DAEBET_' || s.code, 'artikelnummer_lieferant', s.code, 'bezeichnung', s.name,
        'easybill_id', null, 'erstellt_am', now()));
    end if;
    update artikel set ep_lieferant = s.ep, vp_knecht = round(s.ep * 1.25), einheit = 'm³' where id = art;
    insert into staffelstufe (staffelgruppe_id, artikel_id, menge_von, menge_bis, reihenfolge) values (sg, art, s.von, s.bis, nr);
  end loop;

  update staffelgruppe set abrechnung_modus = 'pro_einheit' where id = sg;
  update ressourcenzeile set mindestmenge = 4 where staffelgruppe_id = sg;
end $$;
