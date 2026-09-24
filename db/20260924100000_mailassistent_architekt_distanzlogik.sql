-- Mail-Assistent: Distanzlogik-Funktion (wie bei "Kundenanfrage Erstkontakt")
-- auch auf den Ast "Architekt/Planer" setzen. Die alte Rueckfrage-Vorlage
-- "Architektenanfragen / Devis-Anfragen" (Absagen/Zusagen) wird dabei in
-- einen neuen Zweig "Anfrage pruefen (Absagen/Zusagen)" mit zwei normalen
-- Vorlagen umgewandelt - die alte Vorlage wird nur ausgeblendet (aktiv=false),
-- nicht geloescht.
do $$
declare
  v_ast_id uuid;
  v_zweig_id uuid;
  v_alte_vorlage_id uuid;
  v_naechste_zweig_reihenfolge int;
begin
  select id into v_ast_id from mailassistent_ast where titel = 'Architekt/Planer' limit 1;
  if v_ast_id is null then
    raise notice 'Ast "Architekt/Planer" nicht gefunden - nichts getan.';
    return;
  end if;

  -- Distanzlogik-Funktion auf den Ast setzen, falls noch nicht vorhanden.
  update mailassistent_ast
  set ast_funktion = jsonb_build_object('typ', 'distanzlogik', 'umkreis_minuten', 35)
  where id = v_ast_id and (ast_funktion is null or ast_funktion->>'typ' is distinct from 'distanzlogik');

  select coalesce(max(reihenfolge), -1) + 1 into v_naechste_zweig_reihenfolge
  from mailassistent_zweig where ast_id = v_ast_id;

  insert into mailassistent_zweig (ast_id, titel, entscheidung, reihenfolge)
  values (v_ast_id, 'Anfrage prüfen (Absagen/Zusagen)', 'mitarbeiter', v_naechste_zweig_reihenfolge)
  returning id into v_zweig_id;

  select id into v_alte_vorlage_id from mailassistent_vorlage
  where richtung = 'antworten' and typ = 'rueckfrage' and titel = 'Architektenanfragen / Devis-Anfragen'
  limit 1;

  if v_alte_vorlage_id is not null then
    insert into mailassistent_vorlage (richtung, titel, typ, inhalt, verbindlichkeit, zweig_id, reihenfolge)
    select 'antworten', label, 'einfach', inhalt, 'angepasst', v_zweig_id, reihenfolge
    from mailassistent_vorlage_antwort
    where vorlage_id = v_alte_vorlage_id;

    update mailassistent_vorlage set aktiv = false where id = v_alte_vorlage_id;
  end if;
end $$;
