-- Naturteich/Schwimmteich > Folie und Vlies: zwei Artikel bei Knechtgarten (Einkaufspreise aus der Offerte Contec),
-- Verkauf = Einkauf / 0.75 (25 % Rabatt auf dem Endkundenpreis). Die Freitext-Positionen werden durch die Artikel ersetzt,
-- Menge = Folienfläche inkl. Zuschlag.
do $$
declare
  kg uuid; ot uuid; opt uuid; jz jsonb; f_folie uuid; a_vlies uuid := gen_random_uuid(); a_epdm uuid := gen_random_uuid(); n int;
begin
  select id into kg from lieferant where name = 'Knechtgarten';
  select id into ot from offertentyp where name = 'Naturteich/Schwimmteich' and papierkorb_am is null;
  select ao.id into opt from auswahloption ao join auswahlfeld f on f.id = ao.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt s on s.id = t.arbeitsschritt_id
   where s.offertentyp_id = ot and s.name = 'Folie und Vlies' and ao.name = 'Teichfolie verlegen';
  select id into f_folie from term where offertentyp_id = ot and name = 'Folienfläche inkl. Zuschlag';
  if kg is null or opt is null or f_folie is null then raise exception 'Grundlagen nicht gefunden'; end if;
  if exists (select 1 from artikel where artikelnummer_knecht in ('KNECHT_TEICH_VLIES_800', 'KNECHT_TEICH_EPDM_15')) then raise exception 'Artikel existieren schon'; end if;

  insert into artikel (id, lieferant_id, kategorie, artikelnummer_knecht, artikelnummer_lieferant, bezeichnung, einheit, ep_lieferant, vp_knecht, waehrung, wechselkurs, mwst_satz_pct, anmerkung, sync_easybill, sync_offertentool, sync_webtool, haendischer_abgleich, preis_gesperrt)
  values
    (a_vlies, kg, 'material', 'KNECHT_TEICH_VLIES_800', 'Contec.flex 08.100.80', 'Contec.flex Schutzvlies B, 800 g/m²', 'm²', 5.05, round(5.05 / 0.75, 2), 'CHF', 1, 8.1,
     'Schutzvlies für Teichfolie. Einkauf 5.05, Verkauf = Einkauf / 0.75 (25 % Rabatt auf dem Endkundenpreis).', false, false, false, true, false),
    (a_epdm, kg, 'material', 'KNECHT_TEICH_EPDM_15', 'Contec.proof 01.100.31', 'Contec.proof Kautschukabdichtung EPDM Water, 1.5 mm', 'm²', 31.15, round(31.15 / 0.75, 2), 'CHF', 1, 8.1,
     'Teichfolie EPDM 1.5 mm. Einkauf 31.15, Verkauf = Einkauf / 0.75 (25 % Rabatt auf dem Endkundenpreis).', false, false, false, true, false);

  select to_jsonb(rz) into jz from ressourcenzeile rz where rz.option_id = opt and rz.kategorie = 'personal' order by rz.reihenfolge limit 1;
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', 3, 'kategorie', 'material', 'artikel_id', a_vlies,
    'menge_ausdruck', jsonb_build_object('id', f_folie, 'ref', 'term'), 'notiz', 'Menge = Folienfläche inkl. Zuschlag'));
  insert into ressourcenzeile select * from jsonb_populate_record(null::ressourcenzeile, jz || jsonb_build_object('id', gen_random_uuid(), 'reihenfolge', 4, 'kategorie', 'material', 'artikel_id', a_epdm,
    'menge_ausdruck', jsonb_build_object('id', f_folie, 'ref', 'term'), 'notiz', 'Menge = Folienfläche inkl. Zuschlag'));

  delete from option_freitext_vorlage where option_id = opt;
  update auswahloption set beschreibung = 'Schutzvlies 800 g/m² und Teichfolie EPDM 1.5 mm liefern, verlegen und an den Rändern sauber ausbilden.',
    hinweistext = 'Folie und Vlies rechnen mit der Folienfläche inkl. 12 % Zuschlag.' where id = opt;
  select count(*) into n from ressourcenzeile where option_id = opt;
  if n <> 4 then raise exception 'Erwartet 4 Zeilen, gefunden %', n; end if;
end $$;
