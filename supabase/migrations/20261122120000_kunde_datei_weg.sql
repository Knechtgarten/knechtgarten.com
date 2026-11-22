-- Hochladen in der Kundenkarte wieder entfernt (2026-11-22): eigene Dateien gehören in die Drive-Ablage.
-- Tabelle und Speicher waren leer.
drop policy if exists kunden_dateien_lesen on storage.objects;
drop policy if exists kunden_dateien_schreiben on storage.objects;
drop policy if exists kunden_dateien_loeschen on storage.objects;
-- leerer Speicher «kunden-dateien» bleibt (Supabase erlaubt das Löschen nur über die Storage-API); ohne Zugriffsrechte unbenutzbar
drop table if exists public.kunde_datei;
select (select count(*) from storage.buckets where id = 'kunden-dateien') as bucket, to_regclass('public.kunde_datei') as tabelle;
