-- ============================================================================
-- Pflege-Tool Etappe 4: Speicher fuer Kundenfotos.
-- PRIVAT (Fotos von Kundengaerten/Anlagen): nur eingeloggte Benutzer duerfen
-- lesen/hochladen/loeschen, angezeigt wird ueber zeitlich begrenzte Links
-- (createSignedUrls). Pfad: <kunde_id>/<foto_id>.jpg + <foto_id>_t.jpg (Vorschau).
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pflege-fotos', 'pflege-fotos', false, 10485760, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy "pflege-fotos lesen" on storage.objects
  for select using (bucket_id = 'pflege-fotos' and ist_eingeloggter_benutzer());

create policy "pflege-fotos hochladen" on storage.objects
  for insert with check (bucket_id = 'pflege-fotos' and ist_eingeloggter_benutzer());

create policy "pflege-fotos aktualisieren" on storage.objects
  for update using (bucket_id = 'pflege-fotos' and ist_eingeloggter_benutzer());

create policy "pflege-fotos loeschen" on storage.objects
  for delete using (bucket_id = 'pflege-fotos' and ist_eingeloggter_benutzer());
