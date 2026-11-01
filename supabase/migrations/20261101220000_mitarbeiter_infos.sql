-- ============================================================================
-- Infos an Mitarbeitende (Büro → alle oder bestimmte Gruppen)
-- art 'balken' = Balken auf der Startseite (wegklickbar), 'popup' = Fenster in jedem Tool, muss bestätigt werden.
-- gruppen leer/null = alle. Wegklicken / Bestätigen = Eintrag in mitarbeiter_info_gelesen.
-- Recht: Verwaltung › Infos an Mitarbeitende (Anzeigen = Liste + «gelesen von», Erstellen = Info senden).
-- ============================================================================
create table if not exists mitarbeiter_info (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  text text,
  art text not null default 'balken' check (art in ('balken', 'popup')),
  gruppen uuid[],
  gueltig_von timestamptz not null default now(),
  gueltig_bis timestamptz,
  erstellt_von uuid default auth.uid() references benutzer(id) on delete set null,
  erstellt_am timestamptz not null default now()
);
create index if not exists mitarbeiter_info_gueltig on mitarbeiter_info (gueltig_von, gueltig_bis);

create table if not exists mitarbeiter_info_gelesen (
  info_id uuid not null references mitarbeiter_info(id) on delete cascade,
  benutzer_id uuid not null references benutzer(id) on delete cascade default auth.uid(),
  gelesen_am timestamptz not null default now(),
  primary key (info_id, benutzer_id)
);

-- Lesen: Empfänger sehen ihre Infos, wer Infos verwaltet, sieht alle
alter table mitarbeiter_info enable row level security;
drop policy if exists mitarbeiter_info_lesen on mitarbeiter_info;
drop policy if exists mitarbeiter_info_erstellen on mitarbeiter_info;
drop policy if exists mitarbeiter_info_bearbeiten on mitarbeiter_info;
drop policy if exists mitarbeiter_info_loeschen on mitarbeiter_info;
create policy mitarbeiter_info_lesen on mitarbeiter_info for select using (
  ist_eingeloggter_benutzer() and (
    coalesce(cardinality(gruppen), 0) = 0
    or (select recht_gruppe_id from benutzer where id = auth.uid()) = any(gruppen)
    or recht_darf('verw', 'infos', 'anzeigen')));
create policy mitarbeiter_info_erstellen on mitarbeiter_info for insert
  with check (recht_darf('verw', 'infos', 'erstellen') and erstellt_von = auth.uid());
create policy mitarbeiter_info_bearbeiten on mitarbeiter_info for update
  using (recht_ok('verw', 'infos', 'bearbeiten', erstellt_von)) with check (recht_ok('verw', 'infos', 'bearbeiten', erstellt_von));
create policy mitarbeiter_info_loeschen on mitarbeiter_info for delete
  using (recht_ok('verw', 'infos', 'loeschen', erstellt_von));

alter table mitarbeiter_info_gelesen enable row level security;
drop policy if exists mitarbeiter_info_gelesen_lesen on mitarbeiter_info_gelesen;
drop policy if exists mitarbeiter_info_gelesen_eigene on mitarbeiter_info_gelesen;
create policy mitarbeiter_info_gelesen_lesen on mitarbeiter_info_gelesen for select
  using (benutzer_id = auth.uid() or recht_darf('verw', 'infos', 'anzeigen'));
create policy mitarbeiter_info_gelesen_eigene on mitarbeiter_info_gelesen for insert
  with check (benutzer_id = auth.uid());

-- «Gelesen von»: alle Empfänger mit Login (aktiv, in den Gruppen der Info) und wann sie gelesen haben.
-- Security definer, weil Nicht-Admins die Benutzerliste sonst nicht lesen dürfen.
create or replace function mitarbeiter_info_lesestand(p_info uuid)
returns table (benutzer_id uuid, name text, gelesen_am timestamptz)
language sql stable security definer set search_path = public as $$
  select b.id, coalesce(nullif(b.anzeigename, ''), b.email), g.gelesen_am
  from mitarbeiter_info i
  join benutzer b on b.aktiv and b.rolle is not null and not coalesce(b.ist_platzhalter, false)
    and (coalesce(cardinality(i.gruppen), 0) = 0 or b.recht_gruppe_id = any(i.gruppen))
  left join mitarbeiter_info_gelesen g on g.info_id = i.id and g.benutzer_id = b.id
  where i.id = p_info and recht_darf('verw', 'infos', 'anzeigen')
  order by g.gelesen_am is null, 2;
$$;
grant execute on function mitarbeiter_info_lesestand(uuid) to authenticated;

-- Recht: Projektleiter / Büroteam darf Infos senden und alle Infos bearbeiten (Admin darf immer alles)
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'verw', 'infos', a.aktion, a.wert from recht_gruppe g
cross join (values ('anzeigen', 'A'), ('erstellen', 'J'), ('bearbeiten', 'A'), ('loeschen', 'A')) a(aktion, wert)
where g.schluessel = 'buero'
on conflict (gruppe_id, tool_key, bereich_key, aktion) do update set wert = excluded.wert, geaendert_am = now();
