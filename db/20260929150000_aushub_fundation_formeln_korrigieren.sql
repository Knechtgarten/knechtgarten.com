-- Beläge, Hartflächen: zwei Tippfehler im Aushub und fehlendes Volumen beim
-- Lieferwagentransport der Fundation korrigieren.
--  1. Aushub "Baumaschinen S": Raupenbagger S  "Volumen + 0.45"  -> "Volumen * 0.45"
--  2. Aushub "Kranaushub -20m": Raupenbagger S "Volumen + 0.2"   -> "Volumen * 0.2"
--  3. Fundation Lieferwagen: Chauffeur und Transport "0.75 * 2"  -> "(Volumen Fundation Total * 0.75) * 2"
--     (gleiche Logik wie beim Aushub-Abtransport Lieferwagen)
do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d';
  n1 int; n2 int; n3 int; fund_term jsonb;
begin
  update ressourcenzeile rz
     set menge_ausdruck = jsonb_build_object('op','*','args', rz.menge_ausdruck->'args')
   from auswahloption o, auswahlfeld af, teilschritt ts, arbeitsschritt a
   where rz.option_id = o.id and af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id and a.id = ts.arbeitsschritt_id
     and a.offertentyp_id = ot and a.name = 'Aushub' and o.name in ('Baumaschinen S','Kranaushub -20m')
     and rz.kategorie = 'maschine' and rz.menge_ausdruck->>'op' = '+';
  get diagnostics n1 = row_count;

  select rz.menge_ausdruck->'args'->0 into fund_term
    from ressourcenzeile rz join auswahloption o on o.id = rz.option_id
   where o.name = 'Baumaschinen M' and rz.kategorie = 'personal'
     and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id where ts.name = 'Fundation Kieseinbau LKW')
   limit 1;

  update ressourcenzeile rz
     set menge_ausdruck = jsonb_build_object('op','*','args', jsonb_build_array(
           jsonb_build_object('op','*','args', jsonb_build_array(fund_term, jsonb_build_object('lit', 0.75))),
           jsonb_build_object('lit', 2)))
   from auswahloption o, auswahlfeld af, teilschritt ts
   where rz.option_id = o.id and af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id
     and ts.name = 'Fundation Kieseinbau Lieferwagen'
     and rz.sonderposition_typ_id is not null
     and rz.menge_ausdruck::text like '%0.75%' and rz.menge_ausdruck::text not like '%"ref"%';
  get diagnostics n3 = row_count;
  if n1 <> 2 or n3 <> 2 then raise exception 'Unerwartete Anzahl Zeilen (Aushub %, Fundation %) - nichts geaendert.', n1, n3; end if;
  raise notice 'Korrigiert: Aushub % Zeilen, Fundation Lieferwagen % Zeilen.', n1, n3;
end $$;
