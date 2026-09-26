-- ============================================================================
-- Dokumenten-Suche: Ablage fuer die ZIP-Datei der Browser-Erweiterung im
-- Verwaltungstool - gleiches Muster wie mail-assistent-erweiterung
-- (20260922140000_mailassistent_erweiterung_storage.sql). Oeffentlich lesbar
-- (Download-Link), Hochladen/Aendern nur fuer eingeloggte Benutzer (Seite ist
-- ohnehin admin-gated via ist_buero_oder_admin()).
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('dokumentensuche-erweiterung', 'dokumentensuche-erweiterung', true)
on conflict (id) do nothing;

create policy "dokumentensuche-erweiterung oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'dokumentensuche-erweiterung');

create policy "dokumentensuche-erweiterung hochladen" on storage.objects
  for insert with check (bucket_id = 'dokumentensuche-erweiterung' and auth.uid() is not null);

create policy "dokumentensuche-erweiterung aktualisieren" on storage.objects
  for update using (bucket_id = 'dokumentensuche-erweiterung' and auth.uid() is not null);
