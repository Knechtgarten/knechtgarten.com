-- ============================================================================
-- Offertentool 2027 - Storage-Bereich fuer hochgeladene Kachel-Icons (externe
-- Tools + eigene Links, Admin laedt eigene Bilder direkt vom PC hoch statt
-- nur einen Bild-Link einzufuegen). Oeffentlich lesbar (fuer die Anzeige auf
-- der Startseite), Hochladen/Aendern/Loeschen nur fuer eingeloggte Benutzer
-- (die Seiten, die das nutzen, sind ohnehin admin-gated).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('kachel-icons', 'kachel-icons', true)
on conflict (id) do nothing;

create policy "kachel-icons oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'kachel-icons');

create policy "kachel-icons hochladen" on storage.objects
  for insert with check (bucket_id = 'kachel-icons' and auth.uid() is not null);

create policy "kachel-icons aktualisieren" on storage.objects
  for update using (bucket_id = 'kachel-icons' and auth.uid() is not null);

create policy "kachel-icons loeschen" on storage.objects
  for delete using (bucket_id = 'kachel-icons' and auth.uid() is not null);
