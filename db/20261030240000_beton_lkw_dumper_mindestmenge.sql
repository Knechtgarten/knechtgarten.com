-- Mauern > Fundation > Beton LKW: Raupendumper M mindestens 1 Std.
do $$
declare n int;
begin
  update ressourcenzeile z set mindestmenge = 1
   from auswahloption ao, auswahlfeld af, teilschritt ts, arbeitsschritt s, offertentyp ot, artikel a
   where ao.id = z.option_id and af.id = ao.auswahlfeld_id and ts.id = af.teilschritt_id and s.id = ts.arbeitsschritt_id
     and ot.id = s.offertentyp_id and a.id = z.artikel_id
     and ot.name = 'Mauern' and s.name = 'Fundation' and ao.name = 'Beton LKW' and a.artikelnummer_knecht = 'KNECHT_000114';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Erwartet 1 Zeile, geaendert %', n; end if;
end $$;
