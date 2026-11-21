-- Tagesrechner (Vorlage «Zeit»): Maschinentransport + Projektleitung (Stefan 2026-11-21)
-- Feste Zeilen = menge_ausdruck statt tagesleistung_menge → Tool A zählt sie einmal, sobald der Knopf gewählt ist (nicht x Tage).
-- Transport-Stunden = 2 Fahrten (bringen + holen) × hin und zurück Magazin ↔ Kunde + Auf-/Abladen, auf Viertelstunden aufgerundet.
--   Bagger S: wir selber (Polier + Lieferwagen + Anhänger), Auf-/Abladen 2 × 0.5 Std.
--   Bagger M: Isenschmid LKW 2-Achser 18 t, 150.–/Std. (Preisliste 2026), Auf-/Abladen 2 × 1 Std.
--   Bagger L: Isenschmid Anhängerzug / Tieflader, 225.–/Std. (Preisliste 2026), Auf-/Abladen 2 × 1 Std.
-- VP über die Lieferanten-Marge Isenschmid (25 %): 150 → 200, 225 → 300.

-- Artikel Isenschmid
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select l.id, 'logistik', v.lnr, v.nr, v.bez, 'Std.', v.ep, 'CHF', 'normal', false, true, 'Isenschmid Preisliste 2026'
from lieferant l, (values
  ('LKW-2A-18T', 'ISENSCH_LKW_2ACHSER', 'Maschinentransport LKW 2-Achser 18 t (Isenschmid)', 150::numeric),
  ('TIEFLADER',  'ISENSCH_TIEFLADER',   'Maschinentransport Anhängerzug / Tieflader (Isenschmid)', 225)
) v(lnr, nr, bez, ep)
where l.name = 'Isenschmid - Mulden, Transporte'
  and not exists (select 1 from artikel a where a.artikelnummer_knecht = v.nr);

do $$
declare
  ot uuid := '74262461-1f4b-49ee-837a-9e3a1d41c938';
  fz constant text := '9f615d85-f88c-4163-a580-3fa37b47a4c4'; -- Systemwert «Fahrzeit zur Baustelle» (einfach, Std.)
  polier uuid; lw uuid; anh uuid; lkw uuid; tief uuid; pl uuid := '89b21536-9c59-40fb-88ab-9bb1c16e2beb';
  inst uuid; a uuid; t uuid; f uuid; o uuid; i int; k jsonb;
  -- Stunden = aufrunden_viertel(4 × Fahrzeit + Laden)
  std_s jsonb; std_ml jsonb;
begin
  select id into polier from artikel where bezeichnung = 'Polier / Vorarbeiter' order by artikelnummer_knecht limit 1;
  select id into lw   from artikel where artikelnummer_knecht = 'KNECHT_000101';
  select id into anh  from artikel where artikelnummer_knecht = 'KNECHT_000104';
  select id into lkw  from artikel where artikelnummer_knecht = 'ISENSCH_LKW_2ACHSER';
  select id into tief from artikel where artikelnummer_knecht = 'ISENSCH_TIEFLADER';
  std_s  := jsonb_build_object('op','/','args', jsonb_build_array(jsonb_build_object('op','ceil','args', jsonb_build_array(jsonb_build_object('op','*','args', jsonb_build_array(
              jsonb_build_object('op','+','args', jsonb_build_array(jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('lit',4), jsonb_build_object('ref','term','id',fz))), jsonb_build_object('lit',1))),
              jsonb_build_object('lit',4))))), jsonb_build_object('lit',4)), '_einheit', 'Std.');
  std_ml := jsonb_build_object('op','/','args', jsonb_build_array(jsonb_build_object('op','ceil','args', jsonb_build_array(jsonb_build_object('op','*','args', jsonb_build_array(
              jsonb_build_object('op','+','args', jsonb_build_array(jsonb_build_object('op','*','args', jsonb_build_array(jsonb_build_object('lit',4), jsonb_build_object('ref','term','id',fz))), jsonb_build_object('lit',2))),
              jsonb_build_object('lit',4))))), jsonb_build_object('lit',4)), '_einheit', 'Std.');

  -- Maschinentransport unter «Installation, Entsorgung», direkt nach der Baustelleninstallation
  select id into inst from arbeitsschritt where offertentyp_id = ot and name = 'Installation, Entsorgung';
  if not exists (select 1 from teilschritt where arbeitsschritt_id = inst and name = 'Maschinentransport') then
    update teilschritt set reihenfolge = reihenfolge + 1 where arbeitsschritt_id = inst and reihenfolge >= 3;
    insert into teilschritt (arbeitsschritt_id, name, reihenfolge, beschreibung)
    values (inst, 'Maschinentransport', 3, 'Maschinen auf die Baustelle liefern und wieder abholen.') returning id into t;
    insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Bagger', 1) returning id into f;
    -- Bagger S (wir selber)
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
    values (f, 'Bagger S', 1, null, 'Transport durch uns mit Lieferwagen und Anhänger: 2 Fahrten hin und zurück Magazin ↔ Kunde + 2 × 0.5 Std. Auf-/Abladen.', false, false, false, false) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'personal', polier, std_s, 'baukasten', 'Bagger-Transport', 1, 1, 1, 1, 1),
      (o, 'logistik', lw,     std_s, 'baukasten', 'Bagger-Transport', 1, 1, 1, 1, 2),
      (o, 'logistik', anh,    std_s, 'baukasten', 'Bagger-Transport', 1, 1, 1, 1, 3);
    -- Bagger M (Isenschmid LKW)
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
    values (f, 'Bagger M', 2, null, 'Transport extern, Isenschmid LKW 2-Achser (EK 150.–/Std.): 2 Fahrten hin und zurück Magazin ↔ Kunde + 2 × 1 Std. Auf-/Abladen.', false, false, false, false) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'logistik', lkw, std_ml, 'baukasten', 'Bagger-Transport', 1, 1, 1, 1, 1);
    -- Bagger L (Isenschmid Tieflader)
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
    values (f, 'Bagger L', 3, null, 'Transport extern, Isenschmid Anhängerzug / Tieflader (EK 225.–/Std.): 2 Fahrten hin und zurück Magazin ↔ Kunde + 2 × 1 Std. Auf-/Abladen.', false, false, false, false) returning id into o;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge) values
      (o, 'logistik', tief, std_ml, 'baukasten', 'Bagger-Transport', 1, 1, 1, 1, 1);
  end if;

  -- Projektleitung als erster Arbeitsschritt
  if not exists (select 1 from arbeitsschritt where offertentyp_id = ot and name = 'Projektleitung') then
    insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
    values (ot, 'Projektleitung', coalesce((select min(reihenfolge) from arbeitsschritt where offertentyp_id = ot), 1) - 1) returning id into a;
    insert into teilschritt (arbeitsschritt_id, name, reihenfolge) values (a, 'Projektleitung', 1) returning id into t;
    insert into auswahlfeld (teilschritt_id, name, reihenfolge) values (t, 'Projektleitung', 1) returning id into f;
    i := 0;
    for k in select * from jsonb_array_elements(jsonb_build_array(
        jsonb_build_array(2,  'Verschiedene Arbeiten ohne Metallelemente'),
        jsonb_build_array(4,  'Verschiedene Arbeiten inkl. Metallelemente'),
        jsonb_build_array(8,  'Umfassende Metallelemente wie Pergola'),
        jsonb_build_array(12, null),
        jsonb_build_array(16, null))) loop
      i := i + 1;
      insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
      values (f, (k->>0) || ' Std.', i, null, k->>1, false, false, 'Std.', false, false) returning id into o;
      insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
      values (o, 'personal', pl, jsonb_build_object('lit', (k->>0)::numeric, '_einheit', 'Std.'), 'baukasten', 'Projektleitung', 1, 1, 1, 1, 1);
    end loop;
  end if;
end $$;

select artikelnummer_knecht, bezeichnung, ep_lieferant, vp_knecht from artikel where artikelnummer_knecht in ('ISENSCH_LKW_2ACHSER', 'ISENSCH_TIEFLADER');
