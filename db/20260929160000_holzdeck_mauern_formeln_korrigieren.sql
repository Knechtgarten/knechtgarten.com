-- Holzdeck und Mauern: gleiche Korrekturen wie bei den Belaegen
--  1. Aushub "Baumaschinen S" und "Kranaushub -20m": Raupenbagger S "Volumen + x" -> "Volumen * x"
--  2. Fundation "Kieseinbau Lieferwagen": Chauffeur und Transport "0.75 * 2" -> "(Volumen * 0.75) * 2"
--     (Volumen = derselbe Wert wie bei den Personal-Zeilen derselben Option)
do $$
declare
  v record; n1 int; n3 int; fund_term jsonb; tot1 int := 0; tot3 int := 0;
begin
  for v in select id, name from offertentyp where name in ('Holzdeck','Mauern') and papierkorb_am is null loop
    update ressourcenzeile rz
       set menge_ausdruck = jsonb_build_object('op','*','args', rz.menge_ausdruck->'args')
      from auswahloption o, auswahlfeld af, teilschritt ts, arbeitsschritt a
     where rz.option_id = o.id and af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id and a.id = ts.arbeitsschritt_id
       and a.offertentyp_id = v.id and a.name = 'Aushub' and o.name in ('Baumaschinen S','Kranaushub -20m')
       and rz.kategorie = 'maschine' and rz.menge_ausdruck->>'op' = '+';
    get diagnostics n1 = row_count;

    select rz.menge_ausdruck->'args'->0 into fund_term
      from ressourcenzeile rz join auswahloption o on o.id = rz.option_id
     where o.name = 'Fundation Kieseinbau Lieferwagen' and rz.kategorie = 'personal' and rz.menge_ausdruck->>'op' = '*'
       and rz.menge_ausdruck->'args'->0 ? 'ref'
       and o.auswahlfeld_id in (select af.id from auswahlfeld af join teilschritt ts on ts.id = af.teilschritt_id
                                  join arbeitsschritt a on a.id = ts.arbeitsschritt_id where a.offertentyp_id = v.id)
     limit 1;

    update ressourcenzeile rz
       set menge_ausdruck = jsonb_build_object('op','*','args', jsonb_build_array(
             jsonb_build_object('op','*','args', jsonb_build_array(fund_term, jsonb_build_object('lit', 0.75))),
             jsonb_build_object('lit', 2)))
      from auswahloption o, auswahlfeld af, teilschritt ts, arbeitsschritt a
     where rz.option_id = o.id and af.id = o.auswahlfeld_id and ts.id = af.teilschritt_id and a.id = ts.arbeitsschritt_id
       and a.offertentyp_id = v.id and o.name = 'Fundation Kieseinbau Lieferwagen'
       and rz.sonderposition_typ_id is not null
       and rz.menge_ausdruck::text like '%0.75%' and rz.menge_ausdruck::text not like '%"ref"%';
    get diagnostics n3 = row_count;
    raise notice '%: Aushub % Zeilen, Fundation Lieferwagen % Zeilen korrigiert.', v.name, n1, n3;
    if n1 <> 2 or n3 <> 2 then raise exception '% : unerwartete Anzahl (Aushub %, Fundation %) - nichts geaendert.', v.name, n1, n3; end if;
  end loop;
end $$;
