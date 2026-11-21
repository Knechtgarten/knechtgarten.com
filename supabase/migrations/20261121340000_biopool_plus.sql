-- Pool › Wasseraufbereitung Bio: Zusatzoption «+ Biopool Plus» (Mehrfachauswahl, zusätzlich zur Füllung) (Stefan 2026-11-21)
-- Zeilen wie DA-GEN RX (Aufbereitung mit Filtersteuerung), aber ohne Wasserstandsregler, PE-Sicherheitsbehälter, Magnetventil
-- und Flockungsmittel (APF). Arbeit: Polier Wassergärten + Gartenarbeiter je 18 Std.
do $$
declare
  dagen uuid; feld uuid; neu uuid;
begin
  select o.id into dagen from auswahloption o join auswahlfeld f on f.id = o.auswahlfeld_id join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
  where a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t.name = 'Aufbereitung mit Filtersteuerung' and o.name = 'DA-GEN RX';
  select f.id into feld from auswahlfeld f join teilschritt t on t.id = f.teilschritt_id join arbeitsschritt a on a.id = t.arbeitsschritt_id
  where a.offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and t.name = 'Wasseraufbereitung Bio';
  if dagen is null or feld is null then raise exception 'DA-GEN RX oder Wasseraufbereitung Bio nicht gefunden'; end if;
  if exists (select 1 from auswahloption where auswahlfeld_id = feld and name = '+ Biopool Plus') then return; end if;

  -- vor «+ Brienzer Kies» einreihen
  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, ist_standard, mengenoption, mehrfachauswahl, ist_eigene_offertenposition)
  values (feld, '+ Biopool Plus', 5,
    'Biopool-Plus-Modul liefern, installieren und in Betrieb nehmen, inkl. sämtlicher Zusatzgeräte und Startchemie.',
    'Zusätzlich zur Füllung wählbar. Wie DA-GEN RX, aber ohne Wasserstandsregler, Sicherheitsbehälter, Magnetventil und Flockungsmittel. 2 Personen je 18 Std.',
    false, false, true, false) returning id into neu;

  insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, menge_formel_modus, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
  select neu, 'personal', ar.id, '{"lit": 18, "_einheit": "Std."}', 'baukasten', 'Biopool Plus', 1, 1, 1, 1, x.rf
  from (values ('KNECHT_000015', 1), ('KNECHT_000005', 2)) x(nr, rf) join artikel ar on ar.artikelnummer_knecht = x.nr;

  -- übrige Zeilen 1:1 von DA-GEN RX (inkl. «DA-Gen RX anhand Poolgrösse»)
  insert into ressourcenzeile
  select (jsonb_populate_record(null::ressourcenzeile, to_jsonb(r) || jsonb_build_object('id', gen_random_uuid(), 'option_id', neu))).*
  from ressourcenzeile r left join artikel ar on ar.id = r.artikel_id
  where r.option_id = dagen and r.kategorie <> 'personal'
    and coalesce(ar.artikelnummer_knecht, '') not in ('AQUASOL_081131', 'MIDASP_392', 'AQUASOL_081083', 'AQUASOL_024035');
end $$;

select o.name, o.mehrfachauswahl, coalesce(ar.artikelnummer_knecht, 'Staffel') nr, left(coalesce(ar.bezeichnung, ''), 45) bez, r.menge_ausdruck->>'lit' m
from auswahloption o join ressourcenzeile r on r.option_id = o.id left join artikel ar on ar.id = r.artikel_id
where o.name = '+ Biopool Plus' order by r.reihenfolge;
