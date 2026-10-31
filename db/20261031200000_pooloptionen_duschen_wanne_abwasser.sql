-- Pooloptionen > Duschen: zwei weitere Zusatzoptionen
--  "Zusatz: Fundament mit Duschwanne": Artikel Fundament-Duschwanne-Kombination (Grütter Metallwaren, Platzhalterpreis CHF 1200)
--  "Zusatz: Abwasserleitung Dusche verlegen": Tageseinsatz (Mengenoption Tag), Kopie des Tageseinsatzes "Bagger S" vom Regenwassertank
--   (Polier + Gartenarbeiter 9 Std., Bagger S 3 Std., 1 m3 Deponie, 15 m PP-Rohr, 3 Muffen, 3 Bogen, 1 Std. Geräte)
do $$
declare
  af_id uuid; fund uuid; src uuid; gr uuid; kombi uuid := gen_random_uuid(); opt_w uuid := gen_random_uuid(); opt_a uuid := gen_random_uuid();
  j jsonb; jz jsonb; r record; n int;
begin
  select ao.auswahlfeld_id, ao.id into af_id, fund from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Duschen' and ao.name = 'Zusatz: Fundament Dusche';
  select ao.id into src from auswahloption ao join auswahlfeld af on af.id = ao.auswahlfeld_id join teilschritt ts on ts.id = af.teilschritt_id
    join arbeitsschritt s on s.id = ts.arbeitsschritt_id join offertentyp ot on ot.id = s.offertentyp_id
   where ot.name = 'Regenwassertank' and ot.papierkorb_am is null and ts.name = 'Zusatzarbeiten' and ao.name = 'Bagger S';
  select id into gr from lieferant where name = 'Grütter Metallwaren AG';
  if af_id is null or src is null or gr is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = af_id and name in ('Zusatz: Fundament mit Duschwanne', 'Zusatz: Abwasserleitung Dusche verlegen')) then raise exception 'Optionen existieren schon'; end if;

  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values (kombi, gr, 'material', 'GRTTER_FUNDAMENT_DUSCHWANNE', 'GRTTER_FUNDAMENT_DUSCHWANNE', 'Fundament-Duschwanne-Kombination Edelstahl für Dusche', 'Stk.', null, 1200, 'CHF', 1, 8.1,
          'Platzhalterpreis CHF 1200 (Verkauf), noch nicht bei Grütter Metallwaren bestätigt.', false, false, false, true, false);

  -- Fundament mit Duschwanne (Vorlage: Zusatz Fundament Dusche)
  select to_jsonb(x) into j from auswahloption x where x.id = fund;
  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = fund and rz.reihenfolge = 1;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt_w, 'name', 'Zusatz: Fundament mit Duschwanne', 'reihenfolge', 5,
      'beschreibung', 'Fundament mit integrierter Duschwanne für die Dusche liefern und einbauen.',
      'hinweistext', 'Anstelle von «Zusatz: Fundament Dusche» wählen. Inkl. Fundament-Duschwanne-Kombination Edelstahl.'));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
    jz || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_w, 'reihenfolge', 1, 'artikel_id', kombi, 'menge_ausdruck', '{"lit": 1, "_einheit": "Stk."}'::jsonb));

  -- Abwasserleitung (Tageseinsatz, Kopie Regenwassertank)
  select to_jsonb(x) into j from auswahloption x where x.id = src;
  insert into auswahloption select * from jsonb_populate_record(null::auswahloption,
    j || jsonb_build_object('id', opt_a, 'auswahlfeld_id', af_id, 'name', 'Zusatz: Abwasserleitung Dusche verlegen', 'reihenfolge', 6,
      'mehrfachauswahl', true, 'ist_standard', false, 'optionsgruppe_id', null, 'optionsgruppe_name', null,
      'beschreibung', 'Abwasserleitung für die Dusche graben und PP-Leitung verlegen. Inkl. Material und Entsorgung des Aushubs.',
      'hinweistext', E'Menge = Anzahl Tageseinsätze (auch 0.5 oder 1.5)\nPro Tag: 15 m PP-Rohr, 3 Muffen, 3 Bogen, 1 m³ Aushub, Bagger 3 Std.'));
  for r in select rz.* from ressourcenzeile rz where rz.option_id = src order by rz.reihenfolge loop
    insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile,
      to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', opt_a));
  end loop;

  select count(*) into n from ressourcenzeile where option_id = opt_a;
  if n <> 8 then raise exception 'Erwartet 8 Zeilen für die Abwasserleitung, gefunden %', n; end if;
end $$;
