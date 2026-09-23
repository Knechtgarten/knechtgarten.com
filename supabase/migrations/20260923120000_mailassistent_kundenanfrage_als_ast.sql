-- Mail-Assistent: "Kundenanfragen" als eigener Ast im Ast/Zweig-Modell statt
-- als separater Navigationspunkt. Erzeugt einen Ast "Kundenanfrage
-- Erstkontakt" mit ast_funktion {typ:'distanzlogik', ...} (uebernimmt die
-- Werte aus mailassistent_distanzlogik_meta), einen Zweig darunter, haengt
-- alle bisherigen richtung='kundenanfrage'-Vorlagen an diesen Zweig
-- (richtung -> 'antworten') und verknuepft alle Partnerbetriebe mit dem
-- neuen Ast. Alte Tabellen (mailassistent_distanzlogik_meta) bleiben
-- unangetastet stehen, werden nur nicht mehr vom Code gelesen.
do $$
declare
  v_ast_id uuid;
  v_zweig_id uuid;
  v_meta record;
begin
  select * into v_meta from mailassistent_distanzlogik_meta limit 1;

  insert into mailassistent_ast (titel, anwenden_bei, reihenfolge, ast_funktion)
  values (
    'Kundenanfrage Erstkontakt',
    v_meta.wann_anwenden,
    (select coalesce(max(reihenfolge), -1) + 1 from mailassistent_ast),
    jsonb_build_object(
      'typ', 'distanzlogik',
      'umkreis_minuten', coalesce(v_meta.partner_umkreis_minuten, 35),
      'hinweistext', coalesce(v_meta.partner_hinweistext, ''),
      'erklaerung', coalesce(v_meta.distanz_erklaerung, ''),
      'absagetext', coalesce(v_meta.absage_text, '')
    )
  )
  returning id into v_ast_id;

  insert into mailassistent_zweig (ast_id, titel, entscheidung, reihenfolge)
  values (v_ast_id, 'Antwort auswählen', 'mitarbeiter', 0)
  returning id into v_zweig_id;

  update mailassistent_vorlage
  set richtung = 'antworten',
      zweig_id = v_zweig_id,
      verbindlichkeit = coalesce(verbindlichkeit, 'angepasst')
  where richtung = 'kundenanfrage';

  update mailassistent_partnerbetrieb set ast_id = v_ast_id;
end $$;
