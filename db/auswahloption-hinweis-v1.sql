-- ============================================================================
-- Offertentool 2027 - Hinweistext + Hinweisbild pro Auswahloption.
--
-- Vorbereitung fuer eine spaetere Anzeige in Tool A: beim Ueberfahren des
-- Options-Buttons mit der Maus sollen Hinweistext und Hinweisbild (falls
-- vorhanden, gemeinsam) als Tooltip erscheinen. Diese Migration legt nur die
-- Datenfelder + den Storage-Bereich fuer die Bilder an - die eigentliche
-- Tooltip-Anzeige in Tool A folgt in einer separaten Etappe.
-- ============================================================================

alter table auswahloption add column if not exists hinweistext text null;
alter table auswahloption add column if not exists hinweisbild_url text null;

insert into storage.buckets (id, name, public)
values ('auswahloption-hinweisbilder', 'auswahloption-hinweisbilder', true)
on conflict (id) do nothing;

create policy "auswahloption-hinweisbilder oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'auswahloption-hinweisbilder');

create policy "auswahloption-hinweisbilder hochladen" on storage.objects
  for insert with check (bucket_id = 'auswahloption-hinweisbilder' and auth.uid() is not null);

create policy "auswahloption-hinweisbilder aktualisieren" on storage.objects
  for update using (bucket_id = 'auswahloption-hinweisbilder' and auth.uid() is not null);

create policy "auswahloption-hinweisbilder loeschen" on storage.objects
  for delete using (bucket_id = 'auswahloption-hinweisbilder' and auth.uid() is not null);
