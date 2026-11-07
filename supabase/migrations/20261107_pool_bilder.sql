-- Pool-Katalog: Fotos (z. B. Beckenfarben, Lamellen) im öffentlichen Bucket «pool-bilder»; hochladen/löschen nur Büro und Admin
insert into storage.buckets (id, name, public) values ('pool-bilder', 'pool-bilder', true) on conflict (id) do nothing;
drop policy if exists pool_bilder_lesen on storage.objects;
create policy pool_bilder_lesen on storage.objects for select using (bucket_id = 'pool-bilder');
drop policy if exists pool_bilder_schreiben on storage.objects;
create policy pool_bilder_schreiben on storage.objects for insert to authenticated with check (bucket_id = 'pool-bilder' and ist_buero_oder_admin());
drop policy if exists pool_bilder_loeschen on storage.objects;
create policy pool_bilder_loeschen on storage.objects for delete to authenticated using (bucket_id = 'pool-bilder' and ist_buero_oder_admin());
-- Hellgrau: Foto von Stefan (liegt im Tool unter /bilder/pool/)
update pool_katalog set bild_url = '/bilder/pool/farbe-hellgrau.png' where kategorie = 'farbe' and schluessel = 'hellgrau';
update pool_katalog set bild_url = '/bilder/pool/farbe-schwarz.png' where kategorie = 'farbe' and schluessel = 'schwarz';
update pool_katalog set bild_url = '/bilder/pool/farbe-dunkelgrau.png' where kategorie = 'farbe' and schluessel = 'dunkelgrau';
update pool_katalog set bild_url = '/bilder/pool/farbe-anthrazit.png' where kategorie = 'farbe' and schluessel = 'anthrazit';
