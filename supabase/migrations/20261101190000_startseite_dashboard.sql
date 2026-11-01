-- ============================================================================
-- Startseite als Dashboard: Widgets im Raster, pro Person anpassbar,
-- Standard pro Gruppe (legt der Administrator fest).
-- layout = [{ "k": "plan", "x": 0, "y": 0, "w": 8, "h": 5, "opt": {…} }, …]
-- Reihenfolge beim Laden: eigenes Layout -> Standard der Gruppe -> Vorgabe im Code.
-- ============================================================================
create table if not exists startseite_layout (
  benutzer_id uuid primary key references benutzer(id) on delete cascade,
  layout jsonb not null,
  geaendert_am timestamptz not null default now()
);
alter table startseite_layout enable row level security;
drop policy if exists startseite_layout_eigene on startseite_layout;
create policy startseite_layout_eigene on startseite_layout for all
  using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());

create table if not exists startseite_standard (
  recht_gruppe_id uuid primary key references recht_gruppe(id) on delete cascade,
  layout jsonb not null,
  geaendert_am timestamptz not null default now()
);
alter table startseite_standard enable row level security;
drop policy if exists startseite_standard_lesen on startseite_standard;
drop policy if exists startseite_standard_admin on startseite_standard;
create policy startseite_standard_lesen on startseite_standard for select using (ist_eingeloggter_benutzer());
create policy startseite_standard_admin on startseite_standard for all using (ist_admin()) with check (ist_admin());
