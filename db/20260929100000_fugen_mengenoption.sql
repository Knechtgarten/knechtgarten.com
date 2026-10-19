-- ============================================================================
-- Beläge, Hartflächen: Fugen mit manueller Mengenangabe statt Abhängigkeit
-- von der Belagsfläche.
-- Die 6 Fugen-Optionen werden zu "Mengenoptionen" (wie "Schnitt gerade"): beim
-- Anwählen erscheint ein Feld für die Fugenmenge (m²), und die Zeilen rechnen
-- "Faktor x eingetragene Menge". Aus "Fläche aller Beläge * 0.015" wird also
-- nur noch "0.015" (der Faktor pro m²).
-- Rückgängig: Faktor wieder mit dem Systemwert-Term "Fläche aller Beläge"
-- (systemwert_key belag_flaeche_alle) multiplizieren und mengenoption=false.
-- ============================================================================
do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d';  -- "Beläge, Hartflächen" (neu)
  t_alle uuid;
  opt_ids uuid[];
  anz_opt int; anz_rz int; rest int;
begin
  select id into t_alle from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche_alle';
  select array_agg(o.id) into opt_ids
    from auswahloption o
    join auswahlfeld af on af.id = o.auswahlfeld_id
    join teilschritt ts on ts.id = af.teilschritt_id
    join arbeitsschritt a on a.id = ts.arbeitsschritt_id
   where a.offertentyp_id = ot and ts.name = 'Fugen';

  update auswahloption set mengenoption = true, mengenoption_einheit = 'm²'
   where id = any (opt_ids);
  get diagnostics anz_opt = row_count;

  update ressourcenzeile rz
     set menge_ausdruck = case
       when rz.menge_ausdruck->>'ref' = 'term' and rz.menge_ausdruck->>'id' = t_alle::text
         then '{"lit": 1}'::jsonb
       else rz.menge_ausdruck->'args'->1
     end
   where rz.option_id = any (opt_ids)
     and rz.menge_ausdruck::text like '%' || t_alle::text || '%'
     and ( (rz.menge_ausdruck->>'ref' = 'term' and rz.menge_ausdruck->>'id' = t_alle::text)
        or (rz.menge_ausdruck->>'op' = '*'
            and jsonb_array_length(rz.menge_ausdruck->'args') = 2
            and rz.menge_ausdruck->'args'->0->>'id' = t_alle::text
            and rz.menge_ausdruck->'args'->1 ? 'lit') );
  get diagnostics anz_rz = row_count;

  select count(*) into rest from ressourcenzeile
   where option_id = any (opt_ids) and menge_ausdruck::text like '%' || t_alle::text || '%';
  if rest > 0 then
    raise exception 'Abbruch: % Fugen-Zeilen haben eine andere Formelform und wurden nicht umgebaut - nichts geändert.', rest;
  end if;
  raise notice 'Fugen: % Optionen auf Mengenoption gestellt, % Zeilen umgebaut.', anz_opt, anz_rz;
end $$;
