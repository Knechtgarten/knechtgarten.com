-- ============================================================================
-- Offertentool 2027 - Zweiter Arbeitsschritt fuer Pool: "Fundament"
-- Baut auf schema-v1-pilotkette.sql + pilotkette-testdaten-und-berechnung.sql auf.
-- Zweck: pruefen, ob das Datenmodell mit MEHREREN Arbeitsschritten pro Bauteil
-- funktioniert, und die Kostentabellen-Aggregationsregel live testen:
--   - Maschinenaufwand: ALLES (ueber alle Arbeitsschritte) zu einer Budget-Zeile
--   - Logistik: eine Budget-Zeile PRO Arbeitsschritt
--   - Material: eine "1 Stueck"-Zeile PRO Arbeitsschritt
-- Fundament hat bewusst MEHRERE Logistik- und Material-Ressourcenzeilen, damit
-- die Aggregation (mehrere Zeilen -> eine Zeile) auch wirklich etwas zu tun hat.
-- ============================================================================

do $$
declare
  v_offertentyp_id uuid;
  v_ef_laenge uuid;
  v_ef_breite uuid;
  v_term_fundamentdicke uuid;
  v_term_fundamentvolumen uuid;
  v_term_zeitfaktor_personal uuid;
  v_term_zeitfaktor_maschine uuid;
  v_term_bewehrungsfaktor uuid;
  v_arbeitsschritt_id uuid;
  v_teilschritt_id uuid;
  v_auswahlfeld_id uuid;
  v_option_id uuid;
  v_lieferant_id uuid;
  v_artikel_maurer uuid;
  v_artikel_betonmischer uuid;
  v_artikel_betonlieferung uuid;
  v_artikel_kranmiete uuid;
  v_artikel_beton uuid;
  v_artikel_bewehrung uuid;
  v_teilflaeche_id uuid;
begin
  select id into v_offertentyp_id from offertentyp where name = 'Pool/Wasseranlagen';
  select id into v_ef_laenge from eingabefeld where offertentyp_id = v_offertentyp_id and name = 'Poollaenge';
  select id into v_ef_breite from eingabefeld where offertentyp_id = v_offertentyp_id and name = 'Poolbreite';
  select id into v_lieferant_id from lieferant where kuerzel = 'INT';
  select tf.id into v_teilflaeche_id from teilflaeche tf
    join offerte o on o.id = tf.offerte_id where o.titel = 'Testpool Pilot' limit 1;

  -- Neue Konstanten/Formel (pool-spezifisch)
  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (v_offertentyp_id, 'Fundamentdicke', 'konstante', 0.15, 'm', 'Standarddicke Fundamentplatte')
  returning id into v_term_fundamentdicke;

  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (v_offertentyp_id, 'Fundament-Zeitfaktor Personal', 'konstante', 3.5, 'Std/m3', 'Erfahrungswert Maurerzeit pro m3 Fundament')
  returning id into v_term_zeitfaktor_personal;

  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (v_offertentyp_id, 'Fundament-Zeitfaktor Maschine', 'konstante', 1.2, 'Std/m3', 'Erfahrungswert Betonmischer-Laufzeit pro m3 Fundament')
  returning id into v_term_zeitfaktor_maschine;

  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (v_offertentyp_id, 'Bewehrungsfaktor', 'konstante', 80, 'kg/m3', 'Bewehrungsstahl pro m3 Beton')
  returning id into v_term_bewehrungsfaktor;

  insert into term (offertentyp_id, name, typ, ausdruck, einheit, erklaerung)
  values (
    v_offertentyp_id, 'Fundamentvolumen', 'formel',
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','eingabefeld','id', v_ef_laenge),
      jsonb_build_object('ref','eingabefeld','id', v_ef_breite),
      jsonb_build_object('ref','term','id', v_term_fundamentdicke)
    )),
    'm3', 'Betonvolumen der Fundamentplatte'
  )
  returning id into v_term_fundamentvolumen;

  insert into term_abhaengigkeit (term_id, referenziertes_eingabefeld_id) values
    (v_term_fundamentvolumen, v_ef_laenge),
    (v_term_fundamentvolumen, v_ef_breite);
  insert into term_abhaengigkeit (term_id, referenzierter_term_id) values
    (v_term_fundamentvolumen, v_term_fundamentdicke);

  -- Arbeitsschritt-Hierarchie
  insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
  values (v_offertentyp_id, 'Fundament', 2)
  returning id into v_arbeitsschritt_id;

  insert into teilschritt (arbeitsschritt_id, name, beschreibung, reihenfolge)
  values (v_arbeitsschritt_id, 'Fundamentplatte erstellen',
          'Fundamentplatte betonieren inkl. Bewehrung, Anlieferung und Verdichtung.', 1)
  returning id into v_teilschritt_id;

  insert into auswahlfeld (teilschritt_id, name, mehrfachauswahl, reihenfolge)
  values (v_teilschritt_id, 'Fundament-Ausfuehrung', false, 1)
  returning id into v_auswahlfeld_id;

  insert into auswahloption (auswahlfeld_id, name, reihenfolge)
  values (v_auswahlfeld_id, 'Standard', 1)
  returning id into v_option_id;

  -- Artikelstamm-Ergaenzungen
  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'personal', 'PERS-02', 'INT_PERS-02', 'Maurer', 'Std', 72.00)
  returning id into v_artikel_maurer;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'maschine', 'MASCH-02', 'INT_MASCH-02', 'Betonmischer', 'Std', 45.00)
  returning id into v_artikel_betonmischer;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'logistik', 'LOG-01', 'INT_LOG-01', 'Betonlieferung', 'Fahrt', 180.00)
  returning id into v_artikel_betonlieferung;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'logistik', 'LOG-02', 'INT_LOG-02', 'Kranmiete Fundament', 'Std', 60.00)
  returning id into v_artikel_kranmiete;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'material', 'MAT-02', 'INT_MAT-02', 'Beton C25/30', 'm3', 180.00)
  returning id into v_artikel_beton;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, vp_knecht) values
    (v_lieferant_id, 'material', 'MAT-03', 'INT_MAT-03', 'Bewehrungsstahl', 'kg', 1.80)
  returning id into v_artikel_bewehrung;

  -- Ressourcenzeilen fuer Option "Standard"
  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck) values
  (v_option_id, 'personal', v_artikel_maurer,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_fundamentvolumen),
      jsonb_build_object('ref','term','id', v_term_zeitfaktor_personal)
    ))),
  (v_option_id, 'maschine', v_artikel_betonmischer,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_fundamentvolumen),
      jsonb_build_object('ref','term','id', v_term_zeitfaktor_maschine)
    ))),
  (v_option_id, 'logistik', v_artikel_betonlieferung,
    jsonb_build_object('lit', 1)),
  (v_option_id, 'logistik', v_artikel_kranmiete,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_fundamentvolumen),
      jsonb_build_object('lit', 0.3)
    ))),
  (v_option_id, 'material', v_artikel_beton,
    jsonb_build_object('ref','term','id', v_term_fundamentvolumen)),
  (v_option_id, 'material', v_artikel_bewehrung,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_fundamentvolumen),
      jsonb_build_object('ref','term','id', v_term_bewehrungsfaktor)
    )));

  -- Die bestehende Pilot-Testofferte bekommt auch die Fundament-Option zugewiesen
  if v_teilflaeche_id is not null then
    insert into teilflaeche_auswahl (teilflaeche_id, option_id) values (v_teilflaeche_id, v_option_id);
  end if;
end $$;

-- ----------------------------------------------------------------------------
-- Erwartete Werte zum Nachrechnen (Testofferte 8 x 4 x 1.5m, Fundamentdicke 0.15m):
--   Fundamentvolumen = 8 x 4 x 0.15 = 4.8 m3
--   Maurer:        4.8 x 3.5 = 16.8 Std  x 72.00  = 1'209.60 CHF
--   Betonmischer:  4.8 x 1.2 = 5.76 Std  x 45.00  =   259.20 CHF
--   Betonlieferung: 1 Fahrt            x 180.00  =   180.00 CHF
--   Kranmiete:     4.8 x 0.3 = 1.44 Std x 60.00   =    86.40 CHF
--   Beton:         4.8 m3              x 180.00  =   864.00 CHF
--   Bewehrung:     4.8 x 80 = 384 kg    x 1.80    =   691.20 CHF
--   Total Fundament                               = 3'290.40 CHF
-- ----------------------------------------------------------------------------
with werte as (
  select jsonb_object_agg(w.eingabefeld_id::text, w.wert) as map
  from teilflaeche_eingabefeld_wert w
  join teilflaeche tf on tf.id = w.teilflaeche_id
  join offerte o on o.id = tf.offerte_id
  where o.titel = 'Testpool Pilot'
)
select
  a.name as arbeitsschritt,
  r.kategorie,
  coalesce(r.bezeichnung_override, art.bezeichnung) as bezeichnung,
  round(eval_ausdruck(r.menge_ausdruck, werte.map), 2) as menge,
  art.einheit,
  coalesce(r.preis_override, art.vp_knecht) as preis,
  round(eval_ausdruck(r.menge_ausdruck, werte.map) * coalesce(r.preis_override, art.vp_knecht), 2) as betrag
from ressourcenzeile r
join auswahloption opt on opt.id = r.option_id
join auswahlfeld af on af.id = opt.auswahlfeld_id
join teilschritt ts on ts.id = af.teilschritt_id
join arbeitsschritt a on a.id = ts.arbeitsschritt_id
left join artikel art on art.id = r.artikel_id
cross join werte
where a.name = 'Fundament';
