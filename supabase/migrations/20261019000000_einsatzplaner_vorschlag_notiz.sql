-- Notiz zu einem Pflege-Vorschlag (noch kein Einsatz). Beim Abmachen wird sie in den Einsatz übernommen.
create table planer_vorschlag_notiz (
  kunde_kategorie_id uuid not null references pflege_kunde_kategorie(id) on delete cascade,
  jahr int not null,
  kw int not null check (kw between 1 and 53),
  notiz text not null,
  geaendert_am timestamptz not null default now(),
  primary key (kunde_kategorie_id, jahr, kw)
);
alter table planer_vorschlag_notiz enable row level security;
create policy planer_vorschlag_notiz_voll on planer_vorschlag_notiz for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
alter publication supabase_realtime add table planer_vorschlag_notiz;
