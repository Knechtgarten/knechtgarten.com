-- Unterschriften (Kontakte › Mitarbeitende › Merkmale & Unterschrift) auch entfernen können
drop policy if exists unterschriften_loeschen on storage.objects;
create policy unterschriften_loeschen on storage.objects for delete to authenticated using (bucket_id = 'unterschriften' and ist_buero_oder_admin());
select count(*) as policy from pg_policies where policyname = 'unterschriften_loeschen';
