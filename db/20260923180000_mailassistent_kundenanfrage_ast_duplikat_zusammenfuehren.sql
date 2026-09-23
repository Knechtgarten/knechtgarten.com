-- Mail-Assistent: die Migration 20260923120000 hat einen zweiten Ast
-- "Kundenanfrage Erstkontakt" erzeugt, obwohl Stefan bereits selbst einen
-- gleichnamigen Ast (mit eigener, ausfuehrlicher Anwenden-bei-Logik und
-- eigener Distanzlogik-Funktion) gebaut hatte - Ergebnis: zwei Aeste mit
-- gleichem Titel, die KI fand darum keinen eindeutigen Zweig und landete im
-- Auffangfall. Dieses Skript findet das Migrations-Duplikat ueber seinen
-- eindeutigen Zweig-Titel "Antwort auswählen" (den nur die Migration
-- erzeugt hat), verschiebt diesen Zweig (mit seinen Vorlagen) + alle
-- Partnerbetriebe in den ANDEREN, von Stefan gebauten Ast, und loescht das
-- jetzt leere Duplikat. Die Distanzlogik-Funktion (ast_funktion) von Stefans
-- Ast bleibt unangetastet.
do $$
declare
  v_dup_ast_id uuid;
  v_keep_ast_id uuid;
  v_zweig_id uuid;
begin
  select z.id, z.ast_id into v_zweig_id, v_dup_ast_id
  from mailassistent_zweig z
  join mailassistent_ast a on a.id = z.ast_id
  where a.titel = 'Kundenanfrage Erstkontakt' and z.titel = 'Antwort auswählen'
  limit 1;

  if v_dup_ast_id is null then
    raise notice 'Kein Migrations-Zweig "Antwort auswählen" gefunden - nichts zu tun.';
    return;
  end if;

  select id into v_keep_ast_id from mailassistent_ast
  where titel = 'Kundenanfrage Erstkontakt' and id <> v_dup_ast_id
  limit 1;

  if v_keep_ast_id is null then
    raise notice 'Kein zweiter Ast mit gleichem Titel gefunden - nichts zu tun.';
    return;
  end if;

  update mailassistent_zweig set ast_id = v_keep_ast_id where id = v_zweig_id;
  update mailassistent_partnerbetrieb set ast_id = v_keep_ast_id where ast_id = v_dup_ast_id;
  delete from mailassistent_ast where id = v_dup_ast_id;
end $$;
