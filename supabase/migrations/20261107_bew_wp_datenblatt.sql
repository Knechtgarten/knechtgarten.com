-- Datenblatt der Wärmepumpe (Herstellerkatalog, Seite «Technische Details») als eigenes Dokument im Gesuch.
-- PDF liegt im privaten Bucket bew-unterlagen, gelesen von allen Angemeldeten, geschrieben nur vom Büro.
insert into storage.buckets (id, name, public) values ('bew-unterlagen', 'bew-unterlagen', false) on conflict (id) do nothing;
drop policy if exists bew_unterlagen_lesen on storage.objects;
create policy bew_unterlagen_lesen on storage.objects for select using (bucket_id = 'bew-unterlagen' and ist_eingeloggter_benutzer());
drop policy if exists bew_unterlagen_schreiben on storage.objects;
create policy bew_unterlagen_schreiben on storage.objects for insert with check (bucket_id = 'bew-unterlagen' and ist_buero_oder_admin());
drop policy if exists bew_unterlagen_aendern on storage.objects;
create policy bew_unterlagen_aendern on storage.objects for update using (bucket_id = 'bew-unterlagen' and ist_buero_oder_admin());

alter table public.bew_waermepumpe add column if not exists datenblatt_pfad text, add column if not exists datenblatt_seite int;
update public.bew_waermepumpe set datenblatt_pfad = 'aquark-katalog-2026-kap15.pdf', datenblatt_seite = 2 where modell in ('Silence 30 MSRC 110', 'Silence 30 MSRC 120', 'Silence 30 MSRC 150', 'Silence 30 MSRC 180');
update public.bew_waermepumpe set datenblatt_pfad = 'aquark-katalog-2026-kap15.pdf', datenblatt_seite = 3, vol_min = 75, vol_max = 120 where modell = 'Silence 30 MSRC 430-S';
