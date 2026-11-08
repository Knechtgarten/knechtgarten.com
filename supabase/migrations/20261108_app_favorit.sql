-- Handy-Startseite «Heute»: eigene Schnellzugriffe (Stern auf der Seite «Apps»)
create table if not exists app_favorit (
  benutzer_id uuid not null default auth.uid() references benutzer(id) on delete cascade,
  app_key text not null,
  sortierung integer not null default 0,
  erstellt_am timestamptz not null default now(),
  primary key (benutzer_id, app_key)
);
alter table app_favorit enable row level security;
drop policy if exists app_favorit_eigene on app_favorit;
create policy app_favorit_eigene on app_favorit for all
  using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());
