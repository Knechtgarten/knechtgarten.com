-- Pooloptionen > Wärmepumpe: "Zusatz: isolierte Leitungen pro/ml" bekommt Mehrfachauswahl,
-- damit sie mit einer Wärmepumpe kombinierbar ist (ohne Haken wählt Tool A die Wärmepumpe ab).
do $$
declare n int;
begin
  update auswahloption ao set mehrfachauswahl = true
    from auswahlfeld af, teilschritt ts, arbeitsschritt s, offertentyp ot
   where af.id = ao.auswahlfeld_id and ts.id = af.teilschritt_id and s.id = ts.arbeitsschritt_id and ot.id = s.offertentyp_id
     and ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Wärmepumpe (ohne Grabarbeiten)' and ao.name = 'Zusatz: isolierte Leitungen pro/ml';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Erwartet 1 Option, geändert %', n; end if;
end $$;
