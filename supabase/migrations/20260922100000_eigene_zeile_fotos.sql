-- ============================================================================
-- Offertentool 2027 - Zwei Beleg-Fotos je Eigener Position (z.B. Screenshot
-- der Fremdofferte, die im "Preis zusammenrechnen"-Popup eingefuegt wurde) -
-- gleiches Storage-Muster wie artikel-fotos/kachel-icons/lieferanten-logos.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('eigene-position-fotos', 'eigene-position-fotos', true)
on conflict (id) do nothing;

create policy "eigene-position-fotos oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'eigene-position-fotos');

create policy "eigene-position-fotos hochladen" on storage.objects
  for insert with check (bucket_id = 'eigene-position-fotos' and auth.uid() is not null);

create policy "eigene-position-fotos aktualisieren" on storage.objects
  for update using (bucket_id = 'eigene-position-fotos' and auth.uid() is not null);

create policy "eigene-position-fotos loeschen" on storage.objects
  for delete using (bucket_id = 'eigene-position-fotos' and auth.uid() is not null);

alter table offerte_eigene_zeile add column foto1_url text null;
alter table offerte_eigene_zeile add column foto2_url text null;
