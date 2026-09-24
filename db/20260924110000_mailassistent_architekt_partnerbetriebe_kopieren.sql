-- Mail-Assistent: die Partnerbetriebe von "Kundenanfrage Erstkontakt" 1:1
-- (Name, Adresse, Weiterleitungstext, Pruefstatus) auch beim Ast
-- "Architekt/Planer" hinterlegen - zwei unabhaengige Kopien, keine geteilte
-- Referenz (Schema erlaubt nur einen ast_id pro Partnerbetrieb).
do $$
declare
  v_kundenanfrage_ast_id uuid;
  v_architekt_ast_id uuid;
begin
  select id into v_kundenanfrage_ast_id from mailassistent_ast where titel = 'Kundenanfrage Erstkontakt' limit 1;
  select id into v_architekt_ast_id from mailassistent_ast where titel = 'Architekt/Planer' limit 1;

  if v_kundenanfrage_ast_id is null or v_architekt_ast_id is null then
    raise notice 'Einer der beiden Aeste wurde nicht gefunden - nichts getan.';
    return;
  end if;

  insert into mailassistent_partnerbetrieb (name, adresse, weiterleitung_text, reihenfolge, ast_id, geprueft_ok, geprueft_fehler, geprueft_am)
  select name, adresse, weiterleitung_text, reihenfolge, v_architekt_ast_id, geprueft_ok, geprueft_fehler, geprueft_am
  from mailassistent_partnerbetrieb
  where ast_id = v_kundenanfrage_ast_id;
end $$;
