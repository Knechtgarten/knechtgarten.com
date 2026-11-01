-- ============================================================================
-- Gesamt-Tool: Gruppen & Rechte (Etappe 1 – Datenmodell + Verwaltung)
--
-- Wie bei Easybill: Die Rolle ist eine GRUPPE. Jede Person ist in genau einer
-- Gruppe (benutzer.recht_gruppe_id). Die Rechte hängen an der Gruppe:
-- pro Tool und Bereich (Unterseite) Anzeigen / Erstellen / Bearbeiten / Löschen
-- mit K = Keine, E = Eigene, G = Gruppe, A = Alle (Erstellen: J/N),
-- dazu Zusatzschalter (aktion 'an', J/N) und pro Tool 'sichtbar' (Bereich '_tool').
-- Fehlt ein Eintrag, gilt «Keine». Die Gruppe Administrator darf immer alles.
--
-- Übergang: benutzer.rolle (admin/buero_team/mitarbeitende/service_team) wird von
-- allen Tools und von ist_admin() weiter benutzt. Ein Trigger hält rolle und
-- Gruppe synchron: Gruppe ändern -> rolle = rolle_alt der Gruppe; rolle ändern
-- (alte Masken) -> Standardgruppe dieser Rolle. Die Rechte selbst werden in den
-- Tools erst in Etappe 2 durchgesetzt.
-- ============================================================================

create table if not exists recht_gruppe (
  id uuid primary key default gen_random_uuid(),
  schluessel text unique not null,
  name text not null,
  bereich text not null default 'aussendienst' check (bereich in ('buero', 'aussendienst')),
  ist_admin boolean not null default false,
  rolle_alt text not null check (rolle_alt in ('admin', 'buero_team', 'mitarbeitende', 'service_team')),
  ist_standard_fuer_rolle boolean not null default false,
  sortierung integer not null default 0,
  erstellt_am timestamptz not null default now()
);

create table if not exists recht_eintrag (
  gruppe_id uuid not null references recht_gruppe(id) on delete cascade,
  tool_key text not null,
  bereich_key text not null,
  aktion text not null check (aktion in ('sichtbar', 'anzeigen', 'erstellen', 'bearbeiten', 'loeschen', 'an')),
  wert text not null check (wert in ('K', 'E', 'G', 'A', 'J', 'N')),
  geaendert_am timestamptz not null default now(),
  primary key (gruppe_id, tool_key, bereich_key, aktion)
);

alter table benutzer add column if not exists recht_gruppe_id uuid references recht_gruppe(id) on delete set null;

-- Gruppen -------------------------------------------------------------------
insert into recht_gruppe (schluessel, name, bereich, ist_admin, rolle_alt, ist_standard_fuer_rolle, sortierung) values
  ('admin',     'Administrator',      'buero',        true,  'admin',         true,  10),
  ('buero',     'Büroteam',           'buero',        false, 'buero_team',    true,  20),
  ('va_bau',    'Vorarbeiter Bau',    'aussendienst', false, 'mitarbeitende', false, 30),
  ('va_pflege', 'Vorarbeiter Pflege', 'aussendienst', false, 'service_team',  true,  40),
  ('pool',      'Poolservice',        'aussendienst', false, 'service_team',  false, 50),
  ('hilf',      'Hilfsarbeitende',    'aussendienst', false, 'mitarbeitende', true,  60)
on conflict (schluessel) do nothing;

-- Standardrechte (Vorschlag aus dem Mockup) ----------------------------------
-- Spalten der Kürzel: buero, va_bau, va_pflege, pool, hilf
-- normale Bereiche: 4 Zeichen = Anzeigen, Erstellen (J/N), Bearbeiten, Löschen
-- Schalter: 1 Zeichen J/N
with vorgabe(tool_key, bereich_key, art, werte) as (values
  ('offerten', 'offerten',     'b', 'AJAA AJEE AJEE ENKK KNKK'),
  ('offerten', 'kunden',       'b', 'AJAK AJAK AJAK ANKK KNKK'),
  ('offerten', 'artikel',      'b', 'AJAK ANKK ANKK ANKK KNKK'),
  ('offerten', 'vorlagen',     'b', 'ANKK ANKK KNKK KNKK KNKK'),
  ('offerten', 'einstellungen','s', 'N N N N N'),
  ('offerten', 'easybill',     's', 'J N N N N'),
  ('pend',     'eigenes',      'b', 'EJEE EJEE EJEE EJEE KNKK'),
  ('pend',     'buero',        'b', 'AJAA KNKK KNKK KNKK KNKK'),
  ('pend',     'offerten',     'b', 'AJAA EJEE EJEE KNKK KNKK'),
  ('pend',     'listen',       's', 'J N N N N'),
  ('plan',     'einsaetze',    'b', 'AJAA AJGG AJGG ENKK ENKK'),
  ('plan',     'abwesenheit',  'b', 'AJAA GNKK GNKK EJEE EJEE'),
  ('plan',     'einstellungen','s', 'N N N N N'),
  ('pflege',   'kunden',       'b', 'AJAK ANKK AJAK AJAK KNKK'),
  ('pflege',   'jahresplan',   'b', 'AJAA KNKK AJAA GJGG ENKK'),
  ('pflege',   'kategorien',   'b', 'ANKK KNKK AJAA ANKK KNKK'),
  ('wissen',   'eintraege',    'b', 'AJAK AJAK AJAK AJAK ANKK'),
  ('wissen',   'service',      'b', 'AJAK AJEK AJEK AJEK ANKK'),
  ('mail',     'entwuerfe',    'b', 'EJEE KNKK KNKK KNKK KNKK'),
  ('mail',     'wissen',       'b', 'ANKK KNKK KNKK KNKK KNKK'),
  ('verw',     'personen',     'b', 'AJAK GNEK GNEK ENEK ENEK'),
  ('verw',     'personalien',  's', 'J N N N N'),
  ('verw',     'rechte',       's', 'N N N N N')
),
gruppen(schluessel, nr) as (values ('buero', 1), ('va_bau', 2), ('va_pflege', 3), ('pool', 4), ('hilf', 5)),
zeilen as (
  select g.id gruppe_id, v.tool_key, v.bereich_key, v.art, split_part(v.werte, ' ', gr.nr) code
  from vorgabe v cross join gruppen gr join recht_gruppe g on g.schluessel = gr.schluessel
)
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select gruppe_id, tool_key, bereich_key, a.aktion, substr(code, a.pos, 1)
from zeilen z cross join (values ('anzeigen', 1), ('erstellen', 2), ('bearbeiten', 3), ('loeschen', 4)) a(aktion, pos)
where z.art = 'b'
union all
select gruppe_id, tool_key, bereich_key, 'an', code from zeilen where art = 's'
on conflict do nothing;

-- Tool sichtbar = mindestens ein Bereich ist anzeigbar
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select gruppe_id, tool_key, '_tool', 'sichtbar',
       case when bool_or(aktion = 'anzeigen' and wert <> 'K') then 'J' else 'N' end
from recht_eintrag group by gruppe_id, tool_key
on conflict do nothing;

-- Erstzuteilung: rolle bleibt bei allen gleich ------------------------------
update benutzer b set recht_gruppe_id = g.id
from recht_gruppe g
where b.recht_gruppe_id is null and b.rolle is not null and g.schluessel = (
  case b.rolle
    when 'admin' then 'admin'
    when 'buero_team' then 'buero'
    when 'service_team' then case when exists (
        select 1 from planer_person pp join planer_gruppe pg on pg.id = pp.gruppe_id
        where pp.benutzer_id = b.id and pg.name ilike 'Pool%') then 'pool' else 'va_pflege' end
    when 'mitarbeitende' then case when exists (
        select 1 from planer_person pp join planer_gruppe pg on pg.id = pp.gruppe_id
        where pp.benutzer_id = b.id and pp.ist_vorarbeiter and pg.name ilike '%Gartenbau%') then 'va_bau' else 'hilf' end
  end);

-- rolle <-> Gruppe synchron halten -------------------------------------------
create or replace function benutzer_gruppe_rolle_sync() returns trigger
language plpgsql security definer set search_path = public as $$
declare g recht_gruppe;
begin
  if tg_op = 'UPDATE' and new.recht_gruppe_id is distinct from old.recht_gruppe_id and new.recht_gruppe_id is not null then
    select * into g from recht_gruppe where id = new.recht_gruppe_id;
    new.rolle := g.rolle_alt;
  elsif new.rolle is not null and (tg_op = 'INSERT' or new.rolle is distinct from old.rolle) then
    select * into g from recht_gruppe where id = new.recht_gruppe_id;
    if g.id is null or g.rolle_alt <> new.rolle then
      new.recht_gruppe_id := (select id from recht_gruppe where rolle_alt = new.rolle and ist_standard_fuer_rolle order by sortierung limit 1);
    end if;
  elsif tg_op = 'INSERT' and new.recht_gruppe_id is not null and new.rolle is null then
    select * into g from recht_gruppe where id = new.recht_gruppe_id;
    new.rolle := g.rolle_alt;
  end if;
  return new;
end $$;

drop trigger if exists benutzer_gruppe_rolle_sync on benutzer;
create trigger benutzer_gruppe_rolle_sync before insert or update on benutzer
  for each row execute function benutzer_gruppe_rolle_sync();

-- Zugriff ---------------------------------------------------------------------
alter table recht_gruppe enable row level security;
alter table recht_eintrag enable row level security;
drop policy if exists recht_gruppe_lesen on recht_gruppe;
drop policy if exists recht_gruppe_admin on recht_gruppe;
drop policy if exists recht_eintrag_lesen on recht_eintrag;
drop policy if exists recht_eintrag_admin on recht_eintrag;
create policy recht_gruppe_lesen on recht_gruppe for select using (ist_eingeloggter_benutzer());
create policy recht_gruppe_admin on recht_gruppe for all using (ist_admin()) with check (ist_admin());
create policy recht_eintrag_lesen on recht_eintrag for select using (ist_eingeloggter_benutzer());
create policy recht_eintrag_admin on recht_eintrag for all using (ist_admin()) with check (ist_admin());

-- Für Etappe 2: Gruppe des angemeldeten Benutzers (auch für Nicht-Admins lesbar)
create or replace function meine_recht_gruppe() returns uuid
language sql stable security definer set search_path = public as $$
  select recht_gruppe_id from benutzer where id = auth.uid() and aktiv;
$$;
