-- Mail-Assistent: Datei-Anhaenge pro Vorlage (Verfassen + Antworten), die
-- beim Verwenden dieser Vorlage automatisch mit angehaengt werden koennen
-- (z.B. ein Prospekt, ein Preisblatt). Oeffentlich lesbar (Download-Link/
-- automatisches Anhaengen durch die Erweiterung), Hochladen/Loeschen nur fuer
-- eingeloggte Benutzer - gleiches Muster wie mail-assistent-erweiterung.
insert into storage.buckets (id, name, public)
values ('mailassistent-vorlage-anhaenge', 'mailassistent-vorlage-anhaenge', true)
on conflict (id) do nothing;

create policy "mailassistent-vorlage-anhaenge oeffentlich lesen" on storage.objects
  for select using (bucket_id = 'mailassistent-vorlage-anhaenge');

create policy "mailassistent-vorlage-anhaenge hochladen" on storage.objects
  for insert with check (bucket_id = 'mailassistent-vorlage-anhaenge' and auth.uid() is not null);

create policy "mailassistent-vorlage-anhaenge loeschen" on storage.objects
  for delete using (bucket_id = 'mailassistent-vorlage-anhaenge' and auth.uid() is not null);

create table if not exists mailassistent_vorlage_anhang (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references mailassistent_vorlage(id) on delete cascade,
  dateiname text not null,
  storage_pfad text not null,
  url text not null,
  immer_mitsenden boolean not null default true,
  reihenfolge integer not null default 0,
  groesse_bytes bigint,
  hochgeladen_am timestamptz not null default now()
);
