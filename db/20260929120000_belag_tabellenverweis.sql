-- ============================================================================
-- Beläge, Hartflächen: Belag nicht mehr per Dropdown-Spalte in der Tabelle,
-- sondern per Tabellenverweis bei der Option (Flächen werden in Tool A beim
-- Belag angehakt).
--  1. Optionen der 3 Natursteinbeläge: Tabellenverweis auf Tabelle "Flächen",
--     Spalte "Fläche"
--  2. Mengen-Formeln: "Fläche dieses Belags * x" -> "x" (Menge = Summe der
--     angehakten Flächen wird als Anzahl multipliziert)
--  3. Belag-Haken der drei Teilschritte weg
--  4. bestehende Zuordnungen (Dropdown) in Zeilen-Zuordnung übernehmen
--  5. Dropdown-Spalte "Belag" samt Werten entfernen
--  6. Systemwert-Terms "Fläche dieses Belags"/"Fläche aller Beläge" entfernen
-- ============================================================================
do $$
declare
  ot constant uuid := 'ae8cece8-1768-4507-9405-5a5d3a6fb81d';
  ef_fl uuid; sp_fl uuid; sp_belag uuid; t_belag uuid; t_alle uuid;
  n_opt int; n_rz int; n_zuo int; rest int;
begin
  select e.id into ef_fl from eingabefeld e where e.offertentyp_id = ot and e.name = 'Flächen' and e.ist_tabelle;
  select s.id into sp_fl from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef_fl and s.name = 'Fläche';
  select s.id into sp_belag from eingabefeld_tabelle_spalte s where s.eingabefeld_id = ef_fl and s.ist_dropdown;
  select id into t_belag from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche';
  select id into t_alle  from term where typ = 'systemwert' and systemwert_key = 'belag_flaeche_alle';
  if ef_fl is null or sp_fl is null then raise exception 'Tabelle Flächen / Spalte Fläche nicht gefunden'; end if;

  create temp table _belag_ts on commit drop as
    select ts.id from teilschritt ts join arbeitsschritt a on a.id = ts.arbeitsschritt_id
     where a.offertentyp_id = ot and ts.ist_belag;
  create temp table _belag_opt on commit drop as
    select o.id, af.teilschritt_id from auswahloption o join auswahlfeld af on af.id = o.auswahlfeld_id
     where af.teilschritt_id in (select id from _belag_ts);

  -- 4. Zuordnung übernehmen (vor dem Löschen der Spalte): Zeile -> gewählte Option des Belag-Teilschritts
  update offerte_tabelle_zeile z
     set option_id = oa.option_id
    from offerte_tabelle_wert w, _belag_opt bo, offerte_auswahl oa
   where w.zeile_id = z.id and w.spalte_id = sp_belag and w.text_wert is not null
     and bo.teilschritt_id::text = w.text_wert
     and oa.offerte_id = z.offerte_id and oa.option_id = bo.id;
  get diagnostics n_zuo = row_count;

  -- 1. Tabellenverweis
  update auswahloption set tabellenverweis = jsonb_build_array(jsonb_build_object('eingabefeld_id', ef_fl, 'spalte_id', sp_fl)),
         mengenoption = false
   where id in (select id from _belag_opt);
  get diagnostics n_opt = row_count;

  -- 2. Formeln
  update ressourcenzeile rz
     set menge_ausdruck = case
       when rz.menge_ausdruck->>'ref' = 'term' and rz.menge_ausdruck->>'id' = t_belag::text then '{"lit": 1}'::jsonb
       else rz.menge_ausdruck->'args'->1
     end
   where rz.option_id in (select id from _belag_opt)
     and rz.menge_ausdruck::text like '%' || t_belag::text || '%'
     and ( (rz.menge_ausdruck->>'ref' = 'term' and rz.menge_ausdruck->>'id' = t_belag::text)
        or (rz.menge_ausdruck->>'op' = '*' and jsonb_array_length(rz.menge_ausdruck->'args') = 2
            and rz.menge_ausdruck->'args'->0->>'id' = t_belag::text and rz.menge_ausdruck->'args'->1 ? 'lit') );
  get diagnostics n_rz = row_count;

  select count(*) into rest from ressourcenzeile
   where option_id in (select id from _belag_opt)
     and (menge_ausdruck::text like '%' || t_belag::text || '%' or menge_ausdruck::text like '%' || t_alle::text || '%');
  if rest > 0 then raise exception 'Abbruch: % Zeilen haben eine andere Formelform - nichts geändert.', rest; end if;

  -- 3. Belag-Haken weg
  update teilschritt set ist_belag = false where id in (select id from _belag_ts);

  -- 5. Dropdown-Spalte "Belag" samt Werten
  if sp_belag is not null then
    delete from offerte_tabelle_wert where spalte_id = sp_belag;
    delete from eingabefeld_tabelle_spalte where id = sp_belag;
  end if;

  -- 6. Systemwert-Terms (nirgends mehr verwendet)
select (select count(*) from ressourcenzeile where menge_ausdruck::text like '%' || t_belag::text || '%' or menge_ausdruck::text like '%' || t_alle::text || '%')       + (select count(*) from term where ausdruck::text like '%' || t_belag::text || '%' or ausdruck::text like '%' || t_alle::text || '%')    into rest;
  if rest = 0 then
    delete from term where id in (t_belag, t_alle);
  else
    raise notice 'Systemwert-Terms bleiben (noch % Verweise)', rest;
  end if;

  raise notice 'Fertig: % Optionen mit Tabellenverweis, % Formeln umgebaut, % Zeilen-Zuordnungen übernommen.', n_opt, n_rz, n_zuo;
end $$;
