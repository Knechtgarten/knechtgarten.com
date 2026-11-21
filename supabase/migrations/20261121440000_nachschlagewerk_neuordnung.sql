-- Nachschlagewerk neu geordnet (2026-11-21):
--  * ein Eintrag kann zusätzlich in weiteren Kategorien stehen (auch über Themen hinweg); kategorie_id bleibt der Hauptort
--  * Wissen = ein Buch pro Thema, Kapitel einzeln gespeichert (Verweise auf Einträge im Text: <a data-eintrag="uuid">)
--  * Kurzinfos gehören nur zum Thema: je Thema eine Kategorie «Kurzinfos» (art 'kurz'), die nicht als Kategorie erscheint
--  * Kategorie «Wissen Pool» (leer) fällt weg

alter table public.wissen_eintrag add column if not exists auch_kategorie_ids uuid[] not null default '{}';

create table if not exists public.wissen_kapitel (
  id uuid primary key default gen_random_uuid(),
  thema_id uuid not null references public.wissen_thema(id) on delete cascade,
  titel text not null,
  html text not null default '',
  ebene smallint not null default 1 check (ebene in (1, 2)),
  sortierung integer not null default 0,
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now(),
  geaendert_von uuid references public.benutzer(id)
);
create index if not exists wissen_kapitel_thema_idx on public.wissen_kapitel (thema_id, sortierung);
alter table public.wissen_kapitel enable row level security;
drop policy if exists wissen_kapitel_lesen on public.wissen_kapitel;
create policy wissen_kapitel_lesen on public.wissen_kapitel for select using (ist_eingeloggter_benutzer());
drop policy if exists wissen_kapitel_schreiben on public.wissen_kapitel;
create policy wissen_kapitel_schreiben on public.wissen_kapitel for all
  using (recht_darf('wissen', 'eintraege', 'bearbeiten')) with check (recht_darf('wissen', 'eintraege', 'bearbeiten'));

-- Kurzinfos: bestehende Kurz-Kategorie von «Firma» heisst neu «Kurzinfos»; die anderen Themen bekommen eine
update public.wissen_kategorie set name = 'Kurzinfos Firma' where art = 'kurz' and name = 'Firma & Administration';   -- Name ist eindeutig, darum mit Thema
insert into public.wissen_kategorie (name, art, thema_id, sortierung)
select 'Kurzinfos ' || t.name, 'kurz', t.id, 0 from public.wissen_thema t
where not exists (select 1 from public.wissen_kategorie k where k.thema_id = t.id and k.art = 'kurz');

-- leere Wissens-Kategorie entfernen (Wissen ist jetzt das Buch)
delete from public.wissen_kategorie k where k.art = 'wissen'
  and not exists (select 1 from public.wissen_eintrag e where e.kategorie_id = k.id);

select (select count(*) from public.wissen_kategorie where art = 'kurz') kurz_kats,
       (select count(*) from public.wissen_kategorie where art = 'wissen') wissen_kats;
