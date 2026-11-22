-- Doku-Tool: Ordner «Versand & Rücksendungen» mit der Vorlage «Rücksendung Aqua Solar».
-- Art 'formular' = Original-PDF des Lieferanten als Hintergrund, Angaben werden daraufgeschrieben
-- (Seite doku-formular-live-v1.html). Rechnungskopien liegen im Speicher «doku-anhaenge».


-- erlaubte Arten um 'formular' erweitern
alter table public.doku_vorlage drop constraint if exists doku_vorlage_art_check;
alter table public.doku_vorlage add constraint doku_vorlage_art_check check (art in ('brief', 'abschnitte', 'pdf', 'formular'));
insert into public.doku_ordner (name, farbe, sortierung)
select 'Versand & Rücksendungen', 'petrol', 2
where not exists (select 1 from public.doku_ordner where name = 'Versand & Rücksendungen');

insert into public.doku_vorlage (ordner_id, schluessel, name, beschreibung, html, sortierung, art, datei_pfad)
select o.id, 'ruecksendung_as', 'Rücksendung Aqua Solar', 'Waren-Rücksendung an Aqua Solar, mit Rechnungskopie', '', 10, 'formular', '/vorlagen/aquasolar-ruecksendung.pdf'
from public.doku_ordner o where o.name = 'Versand & Rücksendungen'
and not exists (select 1 from public.doku_vorlage where schluessel = 'ruecksendung_as');

insert into storage.buckets (id, name, public) values ('doku-anhaenge', 'doku-anhaenge', false) on conflict (id) do nothing;
drop policy if exists doku_anhaenge_lesen on storage.objects;
create policy doku_anhaenge_lesen on storage.objects for select using (bucket_id = 'doku-anhaenge' and recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists doku_anhaenge_schreiben on storage.objects;
create policy doku_anhaenge_schreiben on storage.objects for insert with check (bucket_id = 'doku-anhaenge' and recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists doku_anhaenge_loeschen on storage.objects;
create policy doku_anhaenge_loeschen on storage.objects for delete using (bucket_id = 'doku-anhaenge' and recht_wert('doku', 'briefe', 'an') = 'J');

select (select count(*) from public.doku_vorlage where schluessel = 'ruecksendung_as') as vorlage,
       (select count(*) from storage.buckets where id = 'doku-anhaenge') as speicher;
