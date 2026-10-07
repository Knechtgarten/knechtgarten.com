-- Supabase-Sicherheitswarnung (rls_disabled_in_public, 2026-10-03): 14
-- mailassistent_*-Tabellen aus den Migrationen ab 2026-09-22 haben nie
-- Row-Level Security bekommen und waren dadurch ohne Login les-/schreibbar.
-- Gleiches Muster wie in 20260906110000_mailassistent_schema.sql: nur
-- Buero-Team/Admin (ist_buero_oder_admin()). Die Edge Function
-- mail-assistent-draft nutzt den Service-Key und ist davon nicht betroffen.
do $$
declare
  t text;
begin
  foreach t in array array[
    'mailassistent_ast','mailassistent_erweiterung_meta','mailassistent_externe_kontakt_person',
    'mailassistent_externe_kontakte','mailassistent_faelle_abschnitt','mailassistent_faelle_meta',
    'mailassistent_grundlogik_abschnitt','mailassistent_grundlogik_meta','mailassistent_kategorie',
    'mailassistent_schreibstil_abschnitt','mailassistent_unterkategorie','mailassistent_vorlage_anhang',
    'mailassistent_wissen_abschnitt','mailassistent_zweig'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('drop policy if exists %I_buero_admin on %I;', t, t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;
end $$;
