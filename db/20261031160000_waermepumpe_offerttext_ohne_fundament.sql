-- Pooloptionen > Wärmepumpe: "Fundament" aus dem Offerttext gestrichen (Fundament ist jetzt Zusatzoption).
do $$
declare n int;
begin
  update auswahloption ao set beschreibung = replace(ao.beschreibung, 'Inkl. Verbindungsleitungen, Fundament usw.', 'Inkl. Verbindungsleitungen usw.')
    from auswahlfeld af, teilschritt ts, arbeitsschritt s, offertentyp ot
   where af.id = ao.auswahlfeld_id and ts.id = af.teilschritt_id and s.id = ts.arbeitsschritt_id and ot.id = s.offertentyp_id
     and ot.name = 'Pooloptionen' and ot.papierkorb_am is null and s.name = 'Wärmepumpe (ohne Grabarbeiten)'
     and ao.beschreibung like '%Inkl. Verbindungsleitungen, Fundament usw.%';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Erwartet 1 Option, geändert %', n; end if;
end $$;
