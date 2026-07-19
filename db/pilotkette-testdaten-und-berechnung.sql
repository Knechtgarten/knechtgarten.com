-- ============================================================================
-- Offertentool 2027 - Pilot-Kette: Testdaten + Berechnungs-Funktion
-- Baut auf schema-v1-pilotkette.sql auf (muss vorher gelaufen sein).
-- Fuegt EINEN echten Arbeitsschritt ("Aushub") mit echten Artikeln ein und
-- rechnet am Schluss eine Test-Offerte damit durch, um zu pruefen, ob die
-- ganze Kette (Formel -> Ressourcenzeile -> Artikelpreis -> Betrag) stimmt.
--
-- Kunde/Offerte sind klar als Test markiert ("Testkunde Pilot") - Offertentyp,
-- Arbeitsschritt und Artikel sind "echte" Eintraege, die spaeter in Tool B/C
-- normal weitergepflegt werden koennen.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. BERECHNUNGS-FUNKTION
-- Wertet einen Formel-Ausdrucksbaum (siehe term.ausdruck / ressourcenzeile.
-- menge_ausdruck) rekursiv aus. "werte" ist eine JSON-Map {eingabefeld_id: zahl}
-- mit den konkreten Eingaben EINER Teilflaeche. Wird spaeter von Tool A genauso
-- ueber Supabase RPC aufgerufen wie hier zum Testen - eine einzige Rechen-
-- Engine fuer alles, keine doppelte Logik in JS und SQL.
-- ----------------------------------------------------------------------------
create or replace function eval_ausdruck(node jsonb, werte jsonb)
returns numeric
language plpgsql
as $$
declare
  ref_typ text;
  ref_id uuid;
  op text;
  arg jsonb;
  akkumulator numeric;
  teilergebnis numeric;
  term_row term%rowtype;
  i int;
begin
  if node ? 'lit' then
    return (node->>'lit')::numeric;
  end if;

  if node ? 'ref' then
    ref_typ := node->>'ref';
    ref_id := (node->>'id')::uuid;

    if ref_typ = 'eingabefeld' then
      if werte ? ref_id::text then
        return (werte->>ref_id::text)::numeric;
      else
        raise exception 'Kein Wert fuer Eingabefeld % uebergeben', ref_id;
      end if;

    elsif ref_typ = 'term' then
      select * into term_row from term where id = ref_id;
      if not found then
        raise exception 'Term % nicht gefunden', ref_id;
      end if;
      if term_row.typ = 'konstante' then
        return term_row.wert;
      else
        return eval_ausdruck(term_row.ausdruck, werte);
      end if;

    else
      raise exception 'Unbekannter ref-Typ: %', ref_typ;
    end if;
  end if;

  if node ? 'op' then
    op := node->>'op';
    akkumulator := null;
    for i in 0 .. jsonb_array_length(node->'args') - 1 loop
      arg := node->'args'->i;
      teilergebnis := eval_ausdruck(arg, werte);
      if akkumulator is null then
        akkumulator := teilergebnis;
      else
        akkumulator := case op
          when '+' then akkumulator + teilergebnis
          when '-' then akkumulator - teilergebnis
          when '*' then akkumulator * teilergebnis
          when '/' then akkumulator / teilergebnis
          else null
        end;
      end if;
    end loop;
    return akkumulator;
  end if;

  raise exception 'Ungueltiger Ausdruck-Knoten: %', node;
end;
$$;

-- ----------------------------------------------------------------------------
-- 2. TESTDATEN
-- ----------------------------------------------------------------------------
do $$
declare
  v_offertentyp_id uuid;
  v_ef_laenge uuid;
  v_ef_breite uuid;
  v_ef_tiefe uuid;
  v_term_auflockerung uuid;
  v_term_zeitfaktor uuid;
  v_term_aushubvolumen uuid;
  v_arbeitsschritt_id uuid;
  v_teilschritt_id uuid;
  v_auswahlfeld_id uuid;
  v_option_id uuid;
  v_lieferant_id uuid;
  v_artikel_baggerfuehrer uuid;
  v_artikel_bagger uuid;
  v_artikel_entsorgung uuid;
  v_kunde_id uuid;
  v_offerte_id uuid;
  v_teilflaeche_id uuid;
begin
  -- Offertentyp
  insert into offertentyp (name, berechnungsmodell, reihenfolge)
  values ('Pool/Wasseranlagen', 'formel', 1)
  returning id into v_offertentyp_id;

  -- Eingabefelder (Geometrie)
  insert into eingabefeld (offertentyp_id, name, einheit, erklaerung)
  values (v_offertentyp_id, 'Poollaenge', 'm', 'Innenmass Laenge des Beckens')
  returning id into v_ef_laenge;

  insert into eingabefeld (offertentyp_id, name, einheit, erklaerung)
  values (v_offertentyp_id, 'Poolbreite', 'm', 'Innenmass Breite des Beckens')
  returning id into v_ef_breite;

  insert into eingabefeld (offertentyp_id, name, einheit, erklaerung)
  values (v_offertentyp_id, 'Beckentiefe', 'm', 'Mittlere Aushubtiefe')
  returning id into v_ef_tiefe;

  -- Konstante (global, offertentyp_id = null = "Allgemein")
  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (null, 'Auflockerungsfaktor', 'konstante', 1.15, 'Faktor',
          'Aushubmaterial braucht mehr Volumen als der gewachsene Boden')
  returning id into v_term_auflockerung;

  -- Konstante (pool-spezifisch)
  insert into term (offertentyp_id, name, typ, wert, einheit, erklaerung)
  values (v_offertentyp_id, 'Aushub-Zeitfaktor', 'konstante', 0.3, 'Std/m3',
          'Erfahrungswert Baggerleistung pro m3 Aushub')
  returning id into v_term_zeitfaktor;

  -- Formel: Aushubvolumen = Laenge x Breite x Tiefe x Auflockerungsfaktor
  insert into term (offertentyp_id, name, typ, ausdruck, einheit, erklaerung)
  values (
    v_offertentyp_id, 'Aushubvolumen', 'formel',
    jsonb_build_object(
      'op', '*',
      'args', jsonb_build_array(
        jsonb_build_object('ref','eingabefeld','id', v_ef_laenge),
        jsonb_build_object('ref','eingabefeld','id', v_ef_breite),
        jsonb_build_object('ref','eingabefeld','id', v_ef_tiefe),
        jsonb_build_object('ref','term','id', v_term_auflockerung)
      )
    ),
    'm3', 'Aushubvolumen inkl. Auflockerung'
  )
  returning id into v_term_aushubvolumen;

  -- Abhaengigkeiten dokumentieren (Loeschschutz)
  insert into term_abhaengigkeit (term_id, referenziertes_eingabefeld_id) values
    (v_term_aushubvolumen, v_ef_laenge),
    (v_term_aushubvolumen, v_ef_breite),
    (v_term_aushubvolumen, v_ef_tiefe);
  insert into term_abhaengigkeit (term_id, referenzierter_term_id) values
    (v_term_aushubvolumen, v_term_auflockerung);

  -- Arbeitsschritt-Hierarchie
  insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
  values (v_offertentyp_id, 'Aushub', 1)
  returning id into v_arbeitsschritt_id;

  insert into teilschritt (arbeitsschritt_id, name, beschreibung, reihenfolge)
  values (v_arbeitsschritt_id, 'Aushub erstellen',
          'Aushub bis Planum mit Bagger, fachgerechte Entsorgung des Aushubmaterials.', 1)
  returning id into v_teilschritt_id;

  insert into auswahlfeld (teilschritt_id, name, mehrfachauswahl, reihenfolge)
  values (v_teilschritt_id, 'Aushubmaschine', true, 1)
  returning id into v_auswahlfeld_id;

  insert into auswahloption (auswahlfeld_id, name, reihenfolge)
  values (v_auswahlfeld_id, 'Bagger M', 1)
  returning id into v_option_id;

  -- Artikelstamm: interner Lieferant fuer Personal-/Maschinensaetze + ein Entsorgungsartikel
  insert into lieferant (name, kuerzel, sync_typ)
  values ('Eigenleistung / Intern', 'INT', 'manuell')
  returning id into v_lieferant_id;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht,
                        bezeichnung, einheit, vp_knecht)
  values (v_lieferant_id, 'personal', 'PERS-01', 'INT_PERS-01',
          'Baggerfuehrer', 'Std', 78.00)
  returning id into v_artikel_baggerfuehrer;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht,
                        bezeichnung, einheit, vp_knecht)
  values (v_lieferant_id, 'maschine', 'MASCH-01', 'INT_MASCH-01',
          'Bagger M', 'Std', 95.00)
  returning id into v_artikel_bagger;

  insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht,
                        bezeichnung, einheit, vp_knecht)
  values (v_lieferant_id, 'material', 'MAT-01', 'INT_MAT-01',
          'Aushub-Entsorgung', 'm3', 35.00)
  returning id into v_artikel_entsorgung;

  -- Ressourcenzeilen fuer Option "Bagger M"
  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck)
  values (
    v_option_id, 'personal', v_artikel_baggerfuehrer,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_aushubvolumen),
      jsonb_build_object('ref','term','id', v_term_zeitfaktor)
    ))
  );

  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck)
  values (
    v_option_id, 'maschine', v_artikel_bagger,
    jsonb_build_object('op','*','args', jsonb_build_array(
      jsonb_build_object('ref','term','id', v_term_aushubvolumen),
      jsonb_build_object('ref','term','id', v_term_zeitfaktor)
    ))
  );

  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck)
  values (
    v_option_id, 'material', v_artikel_entsorgung,
    jsonb_build_object('ref','term','id', v_term_aushubvolumen)
  );

  -- Test-Kunde + Test-Offerte (klar als Pilot-Test markiert)
  insert into kunde (name) values ('Testkunde Pilot')
  returning id into v_kunde_id;

  insert into offerte (kunde_id, offertentyp_id, titel)
  values (v_kunde_id, v_offertentyp_id, 'Testpool Pilot')
  returning id into v_offerte_id;

  insert into teilflaeche (offerte_id, name)
  values (v_offerte_id, 'Teilbereich 1')
  returning id into v_teilflaeche_id;

  insert into teilflaeche_eingabefeld_wert (teilflaeche_id, eingabefeld_id, wert) values
    (v_teilflaeche_id, v_ef_laenge, 8),
    (v_teilflaeche_id, v_ef_breite, 4),
    (v_teilflaeche_id, v_ef_tiefe, 1.5);

  insert into teilflaeche_auswahl (teilflaeche_id, option_id)
  values (v_teilflaeche_id, v_option_id);
end $$;

-- ----------------------------------------------------------------------------
-- 3. VERIFIKATION
-- Erwartete Werte zum Nachrechnen von Hand:
--   Aushubvolumen = 8 x 4 x 1.5 x 1.15 = 55.2 m3
--   Std (Personal/Maschine) = 55.2 x 0.3 = 16.56 Std
--   Personal:   16.56 x 78.00  = 1'291.68 CHF
--   Maschine:   16.56 x 95.00  = 1'573.20 CHF
--   Material:   55.2  x 35.00  = 1'932.00 CHF
--   Total Aushub                = 4'796.88 CHF
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
where a.name = 'Aushub';
