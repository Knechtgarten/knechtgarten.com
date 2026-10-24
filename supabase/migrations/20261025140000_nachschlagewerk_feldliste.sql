-- ============================================================================
-- Nachschlagewerk: gemeinsame Feldliste (Feldverwaltung bei den Einstellungen).
-- wissen_feld = alle Felder (Bezeichnung, Art, Einheit, Auswahl-Werte), einmal für das ganze Nachschlagewerk.
-- wissen_kategorie.felder = welche Felder die Kategorie verwendet, in Reihenfolge:
--   [{"f": feld_id, "s": true|false}]  (s = pro Stück → Baustein «Mehrfach», sonst Baustein «Infos»)
-- Werte bleiben wie bisher im steckbrief der Einträge/Stücke (über die Bezeichnung).
-- Übernommen aus wissen_merkmal (gleichnamige Felder zusammengelegt); wissen_merkmal bleibt ungenutzt stehen.
-- ============================================================================
create table if not exists wissen_feld (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  art text not null default 'text' check (art in ('text', 'zahl', 'datum', 'janein', 'auswahl')),
  einheit text,
  optionen text[],
  erstellt_am timestamptz not null default now()
);
alter table wissen_feld enable row level security;
drop policy if exists wissen_feld_lesen on wissen_feld;
drop policy if exists wissen_feld_buero on wissen_feld;
create policy wissen_feld_lesen on wissen_feld for select using (ist_eingeloggter_benutzer());
create policy wissen_feld_buero on wissen_feld for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

insert into wissen_feld (name, art, einheit, optionen)
select distinct on (name) name, art, einheit, optionen from wissen_merkmal where kategorie_id is not null
order by name, sortierung
on conflict (name) do nothing;

alter table wissen_kategorie add column if not exists felder jsonb not null default '[]';
update wissen_kategorie k set felder = coalesce((
  select jsonb_agg(jsonb_build_object('f', f.id, 's', m.pro_stueck) order by m.pro_stueck, m.sortierung)
  from wissen_merkmal m join wissen_feld f on f.name = m.name
  where m.kategorie_id = k.id), '[]'::jsonb);
