-- ============================================================================
-- Pflege-Tool Etappe 5: Speicher fuer Angebote / Dokumente (PDF).
-- PRIVAT wie pflege-fotos: nur eingeloggte Benutzer, Anzeige ueber zeitlich
-- begrenzte Links. Pfad: <kunde_id>/<dokument_id>.pdf
-- Verknuepfte Easybill-Angebote werden als Kopie abgelegt (spaetere Aenderungen
-- in Easybill betreffen die Kopie nicht).
-- ============================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pflege-dokumente', 'pflege-dokumente', false, 20971520, array['application/pdf'])
on conflict (id) do nothing;

create policy "pflege-dokumente lesen" on storage.objects
  for select using (bucket_id = 'pflege-dokumente' and ist_eingeloggter_benutzer());

create policy "pflege-dokumente hochladen" on storage.objects
  for insert with check (bucket_id = 'pflege-dokumente' and ist_eingeloggter_benutzer());

create policy "pflege-dokumente aktualisieren" on storage.objects
  for update using (bucket_id = 'pflege-dokumente' and ist_eingeloggter_benutzer());

create policy "pflege-dokumente loeschen" on storage.objects
  for delete using (bucket_id = 'pflege-dokumente' and ist_eingeloggter_benutzer());
