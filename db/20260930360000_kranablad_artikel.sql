-- Kranablad Fontarocca: 24 CHF je Tonne (Mitteilung Fontarocca), VK = EK x 1.05 wie bei den übrigen Fontarocca-Artikeln.
-- Statt Freitext-Position jetzt Artikel-Zeile: Menge = Gewicht der Natursteinmauer in t (Fläche x 1 t/m², wie beim Transport).
do $$
declare fo uuid; a_kr uuid := gen_random_uuid(); o_kr uuid; o_dir uuid; src uuid; j jsonb;
begin
  select id into fo from lieferant where name = 'Fontarocca AG';
  select o.id into o_kr from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id where f.name = 'Transport Natursteine' and o.name = 'Kranablad';
  select o.id into o_dir from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id where f.name = 'Transport Natursteine' and o.name = 'Direkt (gekippt)';
  select rz.id into src from ressourcenzeile rz where rz.option_id = o_dir limit 1;
  if fo is null or o_kr is null or src is null then raise exception 'Grundlage nicht gefunden'; end if;
  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (a_kr, fo, 'logistik', 'FONTAR_KRANABLAD', 'KRANABLAD', 'Kranablad Natursteine Fontarocca', 't', 24, 25.20, 'CHF', 1, 8.1, 'Mitteilung Fontarocca Oktober 2026: 24 CHF je Tonne', false, false, false, true, false);
  delete from option_freitext_vorlage where option_id = o_kr;
  select to_jsonb(rz) into j from ressourcenzeile rz where rz.id = src;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, j || jsonb_build_object('id', gen_random_uuid(), 'option_id', o_kr, 'artikel_id', a_kr, 'kategorie', 'logistik', 'reihenfolge', 1,
      'bezeichnung_override', null, 'verschnitt_prozent', null, 'mindestmenge', null, 'mengenoption_ausgenommen', false));
  update auswahloption set hinweistext = 'Fontarocca liefert in der Regel ohne Ablad (Polen-, Portugal- und Lusernaquader auf Paletten). Kranablad kostet 24 CHF je Tonne. Menge = Gewicht der Natursteinmauer (Fläche x 1 t/m²); bei Polengranit 40er/50er liegt das Gewicht höher (1.15 / 1.3 t/m²), dann die Menge in der Offerte anpassen.' where id = o_kr;
end $$;
