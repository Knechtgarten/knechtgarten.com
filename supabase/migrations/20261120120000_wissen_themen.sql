-- Nachschlagewerk nach Themen (Entscheid Stefan 2026-11-20):
--   Nachschlagewerk = Thema › Kategorie › Eintrag. Maschinen (Kategorien mit art 'geraet') sind ein eigenes Tool
--   «Maschinen & Fahrzeuge» (gleiche Tabellen, eigene Seite maschinen-live-v1.html).
--   Eintragsart pro Eintrag: typ 'kurz' (eine Zeile: Titel + Wert) oder normaler Eintrag.

create table if not exists wissen_thema (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sortierung integer not null default 0,
  erstellt_am timestamptz not null default now()
);
alter table wissen_thema enable row level security;
drop policy if exists wissen_thema_lesen on wissen_thema;
create policy wissen_thema_lesen on wissen_thema for select using (ist_eingeloggter_benutzer());
drop policy if exists wissen_thema_schreiben on wissen_thema;
create policy wissen_thema_schreiben on wissen_thema for all using (recht_darf('wissen', 'eintraege', 'bearbeiten')) with check (recht_darf('wissen', 'eintraege', 'bearbeiten'));

alter table wissen_kategorie add column if not exists thema_id uuid references wissen_thema(id) on delete set null;

-- Eintragsart pro Eintrag: auch 'kurz' erlaubt
alter table wissen_eintrag drop constraint if exists wissen_eintrag_typ_check;
alter table wissen_eintrag add constraint wissen_eintrag_typ_check check (typ in ('geraet', 'produkt', 'wissen', 'kurz'));
update wissen_eintrag e set typ = 'kurz' from wissen_kategorie k where k.id = e.kategorie_id and k.art = 'kurz' and e.typ <> 'kurz';

insert into wissen_thema (name, sortierung) values
  ('Pool & Wasser', 10), ('Garten & Pflanzen', 20), ('Bau & Material', 30), ('Firma', 40)
on conflict (name) do nothing;

update wissen_kategorie set name = 'Wissen Pool' where name = 'Pool & Wasser';
update wissen_kategorie k set thema_id = t.id from wissen_thema t, (values
  ('Poolkomponenten', 'Pool & Wasser'), ('Poolpflegemittel', 'Pool & Wasser'), ('Bewässerung', 'Pool & Wasser'), ('Wissen Pool', 'Pool & Wasser'),
  ('Pflanzen', 'Garten & Pflanzen'), ('Dünger & Substrate', 'Garten & Pflanzen'), ('Spritzmittel', 'Garten & Pflanzen'),
  ('Kleber & Dichtstoffe', 'Bau & Material'), ('Metall & Befestigung', 'Bau & Material'), ('Chemikalien', 'Bau & Material'),
  ('Firma & Administration', 'Firma'), ('Software & Büro', 'Firma')
) z(kat, thema)
where k.name = z.kat and t.name = z.thema and k.art <> 'geraet';

-- Testeinträge weg (archivieren), leere Kategorie «Wissen & Daten» löschen
update wissen_eintrag set archiviert_am = now()
 where id in ('935c84d3-ac3f-4e2b-b3c8-bafabf9807f7', '37cd0708-3668-402d-a155-8c9b005c86ad') and archiviert_am is null;
update wissen_eintrag set kategorie_id = null
 where kategorie_id = (select id from wissen_kategorie where name = 'Wissen & Daten') and archiviert_am is not null;
delete from wissen_kategorie k where k.name = 'Wissen & Daten' and not exists (select 1 from wissen_eintrag e where e.kategorie_id = k.id);

select k.name, k.art, t.name thema from wissen_kategorie k left join wissen_thema t on t.id = k.thema_id order by t.sortierung nulls first, k.sortierung;

-- leere «Geräte»-Kategorien, die ins Nachschlagewerk gehören
update wissen_kategorie set art = 'produkt' where name in ('Bewässerung', 'Software & Büro') and art = 'geraet'
  and not exists (select 1 from wissen_eintrag e where e.kategorie_id = wissen_kategorie.id and e.archiviert_am is null);
update wissen_kategorie k set thema_id = t.id from wissen_thema t
 where (k.name, t.name) in (('Bewässerung', 'Pool & Wasser'), ('Software & Büro', 'Firma')) and k.art <> 'geraet';
