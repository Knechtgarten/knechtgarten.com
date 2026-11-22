-- Kontakte › Dokumente: beliebige Dateien beim Kunden hochladen (PDF, Foto, Bewilligung …),
-- neben den im Doku-Tool erstellten Dokumenten. Rechte wie doku_dokument (Doku-Tools › Briefe erstellen).
-- Leere Vorlagen-Ordner «Transport» und «Kunden» im Doku-Tool fallen weg.

create table if not exists public.kunde_datei (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references public.kunde(id) on delete cascade,
  name text not null,
  storage_pfad text not null,
  mime text,
  groesse bigint,
  drive_datei_id text,
  drive_abgelegt_am timestamptz,
  erstellt_von uuid references public.benutzer(id) default auth.uid(),
  erstellt_am timestamptz not null default now()
);
create index if not exists kunde_datei_kunde_idx on public.kunde_datei (kunde_id, erstellt_am desc);
alter table public.kunde_datei enable row level security;
drop policy if exists kunde_datei_alle on public.kunde_datei;
create policy kunde_datei_alle on public.kunde_datei for all
  using (recht_wert('doku', 'briefe', 'an') = 'J') with check (recht_wert('doku', 'briefe', 'an') = 'J');

insert into storage.buckets (id, name, public) values ('kunden-dateien', 'kunden-dateien', false) on conflict (id) do nothing;
drop policy if exists kunden_dateien_lesen on storage.objects;
create policy kunden_dateien_lesen on storage.objects for select using (bucket_id = 'kunden-dateien' and recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists kunden_dateien_schreiben on storage.objects;
create policy kunden_dateien_schreiben on storage.objects for insert with check (bucket_id = 'kunden-dateien' and recht_wert('doku', 'briefe', 'an') = 'J');
drop policy if exists kunden_dateien_loeschen on storage.objects;
create policy kunden_dateien_loeschen on storage.objects for delete using (bucket_id = 'kunden-dateien' and recht_wert('doku', 'briefe', 'an') = 'J');

delete from public.doku_ordner o where o.name in ('Transport', 'Kunden')
  and not exists (select 1 from public.doku_vorlage v where v.ordner_id = o.id);

select (select count(*) from public.doku_ordner) as ordner, (select count(*) from storage.buckets where id = 'kunden-dateien') as bucket;
