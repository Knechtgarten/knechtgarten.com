-- Rücksendung Aqua Solar: Lieferanten-Katalog (PDF) pro Vorlage, verwaltet in Einstellungen › Doku-Tools.
-- PDF liegt im Speicher «doku-dateien» (katalog/<vorlage>/<datei>.pdf), Angaben in doku_vorlage.einstellungen.katalog
-- ({ pfad, name, stand, seiten }). Beim Hochladen liest die Seite alle Artikelnummern mit Bezeichnung und Seite aus.

alter table public.doku_vorlage add column if not exists einstellungen jsonb not null default '{}'::jsonb;

create table if not exists public.doku_katalog_artikel (
  id bigint generated always as identity primary key,
  vorlage_id uuid not null references public.doku_vorlage(id) on delete cascade,
  nr text not null,
  bez text not null default '',
  seite integer not null
);
create index if not exists doku_katalog_artikel_nr on public.doku_katalog_artikel (vorlage_id, nr);
alter table public.doku_katalog_artikel enable row level security;
drop policy if exists doku_katalog_lesen on public.doku_katalog_artikel;
create policy doku_katalog_lesen on public.doku_katalog_artikel for select using (ist_eingeloggter_benutzer());
drop policy if exists doku_katalog_schreiben on public.doku_katalog_artikel;
create policy doku_katalog_schreiben on public.doku_katalog_artikel for insert with check (recht_wert('doku', 'vorlagen', 'an') = 'J');
drop policy if exists doku_katalog_loeschen on public.doku_katalog_artikel;
create policy doku_katalog_loeschen on public.doku_katalog_artikel for delete using (recht_wert('doku', 'vorlagen', 'an') = 'J');

select (select count(*) from information_schema.columns where table_name = 'doku_vorlage' and column_name = 'einstellungen') as spalte,
       (select count(*) from pg_policies where tablename = 'doku_katalog_artikel') as policies,
       (select string_agg(policyname || ':' || cmd, ', ') from pg_policies where tablename = 'doku_vorlage') as vorlage_policies;
