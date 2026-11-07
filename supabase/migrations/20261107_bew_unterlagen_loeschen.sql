-- Büro darf Dateien im Bucket bew-unterlagen löschen (z. B. ersetzte Pläne)
drop policy if exists bew_unterlagen_loeschen on storage.objects;
create policy bew_unterlagen_loeschen on storage.objects for delete using (bucket_id = 'bew-unterlagen' and ist_buero_oder_admin());
