-- ============================================================================
-- Offertentool 2027 - Storage-Bereich fuer hochgeladene Lieferanten-Logos.
-- Oeffentlich lesbar (Anzeige in der Lieferanten-Liste), Hochladen/Aendern/
-- Loeschen nur fuer eingeloggte Benutzer (Seite ist ohnehin admin-gated).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('lieferanten-logos', 'lieferanten-logos', true)
on conflict (id) do nothing;

create policy "lieferanten-logos oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'lieferanten-logos');

create policy "lieferanten-logos hochladen" on storage.objects
  for insert with check (bucket_id = 'lieferanten-logos' and auth.uid() is not null);

create policy "lieferanten-logos aktualisieren" on storage.objects
  for update using (bucket_id = 'lieferanten-logos' and auth.uid() is not null);

create policy "lieferanten-logos loeschen" on storage.objects
  for delete using (bucket_id = 'lieferanten-logos' and auth.uid() is not null);
