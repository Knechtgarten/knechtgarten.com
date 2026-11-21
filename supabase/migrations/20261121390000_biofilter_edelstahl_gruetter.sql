-- Biofilter-Behälter Edelstahl von Grütter Metallwaren (Stefan 2026-11-21)
-- Preis aus Preisanfrage «Biofilter Kirchgässli» (Gümligen), Mail Silvio Grütter 18.11.2025:
--   Höhe 1500 Fr. 10'250.–, Höhe 1400 Fr. 9'550.– (Durchschnittsgrösse ca. 3.5 × 1.2 × 1.5 m)
-- Option «+ Edelstahlbehälter» (Pool › Wasseraufbereitung Bio, Teich › Biofilter), zusätzlich zur Füllung Classic/Helix
-- (die Füllung bleibt, nur der Körper kommt dazu): Grütter-Behälter + GFK-Gitter ca. 4 m² als gelbe Zeile (Preis fehlt).
insert into artikel (lieferant_id, kategorie, artikelnummer_lieferant, artikelnummer_knecht, bezeichnung, einheit, ep_lieferant, waehrung, mwst_art, preis_gesperrt, sync_offertentool, notiz)
select l.id, 'material', 'BIOFILTER-1500', 'GRUETT_BIOFILTER_1500', 'Biofilter-Behälter Edelstahl ca. 3.5 × 1.2 × 1.5 m (Grütter)', 'Stk.', 10250, 'CHF', 'normal', false, true,
  'Preisanfrage Biofilter Kirchgässli, Grütter 18.11.2025: Höhe 1500 Fr. 10''250.–, Höhe 1400 Fr. 9''550.–'
from lieferant l where l.name = 'Grütter Metallwaren AG'
  and not exists (select 1 from artikel where artikelnummer_knecht = 'GRUETT_BIOFILTER_1500');

do $$
declare f record; neu uuid; beh uuid;
begin
  select id into beh from artikel where artikelnummer_knecht = 'GRUETT_BIOFILTER_1500';
  for f in select f2.id from auswahlfeld f2 join teilschritt t on t.id = f2.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
           where (a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t.name = 'Wasseraufbereitung Bio')
              or (a.offertentyp_id = 'bcc55d19-7e61-4fc8-80d0-0889c3148896' and t.name = 'Biofilter') loop
    if exists (select 1 from auswahloption where auswahlfeld_id = f.id and name = '+ Edelstahlbehälter') then continue; end if;
    insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
    values (f.id, '+ Edelstahlbehälter', 8, 'Biofilter-Behälter aus Edelstahl inkl. GFK-Gitter liefern und versetzen.',
      'Zusätzlich zur Füllung (Classic/Helix bleibt). Grütter-Behälter ca. 3.5 × 1.2 × 1.5 m (EK 10''250.–, Höhe 1400: 9''550.–). GFK-Gitter ca. 4 m²: gelbe Zeile, Preis eintragen.',
      false, false, true, true) returning id into neu;
    insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
    values (neu, 'material', beh, '{"lit": 1, "_einheit": "Stk."}', 'baukasten', 1, 1, 1, 1, 1);
    insert into option_freitext_vorlage (option_id, kategorie, bezeichnung, einheit, notiz, menge_vorschlag, preis_vorschlag, reihenfolge, ist_eigene_offertenposition)
    values (neu, 'material', 'GFK-Gitterrost für Biofilter', 'm²', 'Preis noch nicht im Artikelstamm', 4, null, 2, true);
  end loop;
end $$;

select a.artikelnummer_knecht, a.ep_lieferant, a.vp_knecht, (select count(*) from auswahloption where name = '+ Edelstahlbehälter') optionen
from artikel a where a.artikelnummer_knecht = 'GRUETT_BIOFILTER_1500';
