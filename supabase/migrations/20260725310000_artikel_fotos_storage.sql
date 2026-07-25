-- ============================================================================
-- Offertentool 2027 - Storage-Bereich fuer echte Artikel-Fotos (statt nur
-- eines Bild-Links). Oeffentlich lesbar (Vorschau im Artikelstamm),
-- Hochladen/Aendern/Loeschen nur fuer eingeloggte Benutzer - gleiches Muster
-- wie kachel-icons (siehe 20260725270000_kachel_icons_storage.sql).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('artikel-fotos', 'artikel-fotos', true)
on conflict (id) do nothing;

create policy "artikel-fotos oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'artikel-fotos');

create policy "artikel-fotos hochladen" on storage.objects
  for insert with check (bucket_id = 'artikel-fotos' and auth.uid() is not null);

create policy "artikel-fotos aktualisieren" on storage.objects
  for update using (bucket_id = 'artikel-fotos' and auth.uid() is not null);

create policy "artikel-fotos loeschen" on storage.objects
  for delete using (bucket_id = 'artikel-fotos' and auth.uid() is not null);
