-- Mail-Assistent: Korrektur zu 20260924110000 - der Ast "Kundenanfrage
-- Erstkontakt" wurde inzwischen umbenannt zu "Kundenanfrage Erstkontakt -
-- Weiterleiten an Partnerbetrieb", darum ueber die bekannte, stabile id
-- angesprochen statt ueber den (jetzt veralteten) Titel.
do $$
declare
  v_kundenanfrage_ast_id uuid := '7de34033-1d8e-4231-b988-a28bbfcccb10';
  v_architekt_ast_id uuid;
begin
  select id into v_architekt_ast_id from mailassistent_ast where titel = 'Architekt/Planer' limit 1;

  if v_architekt_ast_id is null then
    raise notice 'Ast "Architekt/Planer" nicht gefunden - nichts getan.';
    return;
  end if;

  insert into mailassistent_partnerbetrieb (name, adresse, weiterleitung_text, reihenfolge, ast_id, geprueft_ok, geprueft_fehler, geprueft_am)
  select name, adresse, weiterleitung_text, reihenfolge, v_architekt_ast_id, geprueft_ok, geprueft_fehler, geprueft_am
  from mailassistent_partnerbetrieb
  where ast_id = v_kundenanfrage_ast_id
    and not exists (
      select 1 from mailassistent_partnerbetrieb p2
      where p2.ast_id = v_architekt_ast_id and p2.name = mailassistent_partnerbetrieb.name
    );
end $$;
