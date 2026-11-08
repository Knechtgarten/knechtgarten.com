-- Tool-Menü am Computer pro Person: welche Tools im Menü stehen (an) und in welcher Reihenfolge (auch Reihenfolge der Kacheln in den Einstellungen).
-- Handy-Schnellzugriff bleibt separat in app_favorit.
create table if not exists tool_menue (
  benutzer_id uuid not null default auth.uid() references benutzer(id) on delete cascade,
  app_key text not null,
  sortierung integer not null default 0,
  an boolean not null default true,
  primary key (benutzer_id, app_key)
);
alter table tool_menue enable row level security;
drop policy if exists tool_menue_eigene on tool_menue;
create policy tool_menue_eigene on tool_menue for all using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());
