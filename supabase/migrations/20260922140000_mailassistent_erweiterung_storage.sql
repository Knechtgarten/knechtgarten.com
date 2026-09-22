-- ============================================================================
-- Mail-Assistent: Ablage fuer die ZIP-Datei der Chrome-Erweiterung im
-- Verwaltungstool (Einstellungen), statt ueber Google Drive zu gehen. Oeffentlich
-- lesbar (Download-Link), Hochladen/Aendern nur fuer eingeloggte Benutzer
-- (Seite ist ohnehin admin-gated) - gleiches Muster wie lieferanten-logos.
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('mail-assistent-erweiterung', 'mail-assistent-erweiterung', true)
on conflict (id) do nothing;

create policy "mail-assistent-erweiterung oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'mail-assistent-erweiterung');

create policy "mail-assistent-erweiterung hochladen" on storage.objects
  for insert with check (bucket_id = 'mail-assistent-erweiterung' and auth.uid() is not null);

create policy "mail-assistent-erweiterung aktualisieren" on storage.objects
  for update using (bucket_id = 'mail-assistent-erweiterung' and auth.uid() is not null);

create table if not exists mailassistent_erweiterung_meta (
  id uuid primary key default gen_random_uuid(),
  version text,
  dateiname text,
  url text,
  hochgeladen_am timestamptz,
  hochgeladen_von text
);
