-- Pool-Konfigurator: Katalog in der Datenbank (vorher fest im Code).
-- kategorie: farbe (Beckenfarbe) | lamelle (Lamellenfarbe) | belag (Sitzbank) | einbauteil | technik
-- gruppe: bei einbauteil skimmer|duese|licht|ablauf|gegen, bei technik filter|pumpe|pflege|wp|nachsp
-- schluessel: fester Kurzname für Farben/Belag (steht so in den gespeicherten Pools)
-- koerper: für welche Beckenkörper der Eintrag gilt (pp, edelstahl, folie)
-- Elektro-Angaben (anschluss … schema) ergeben das Elektriker-Blatt.

create table if not exists pool_katalog (
  id uuid primary key default gen_random_uuid(),
  kategorie text not null check (kategorie in ('farbe','lamelle','belag','einbauteil','technik')),
  gruppe text,
  schluessel text,
  name text not null,
  farbe text, farbe2 text,
  material text[] not null default '{}',
  koerper text[] not null default '{pp}',
  anschluss text, schaltung text, volt text, leistung text, schema text,
  info text, bild_url text,
  sort integer not null default 0,
  aktiv boolean not null default true,
  erstellt_am timestamptz not null default now()
);
create index if not exists pool_katalog_kat on pool_katalog(kategorie, gruppe, sort);
alter table pool_katalog enable row level security;
drop policy if exists pool_katalog_lesen on pool_katalog;
create policy pool_katalog_lesen on pool_katalog for select to authenticated using (ist_eingeloggter_benutzer());
drop policy if exists pool_katalog_schreiben on pool_katalog;
create policy pool_katalog_schreiben on pool_katalog for all to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Startdaten (wie bisher im Code), nur einmal
insert into pool_katalog (kategorie, gruppe, schluessel, name, farbe, farbe2, material, anschluss, schaltung, volt, leistung, schema, sort)
select * from (values
  ('farbe', null, 'weiss', 'Weiss', '#F2F4F5', '#CFE6F2', '{}'::text[], null, null, null, null, null, 1),
  ('farbe', null, 'hellgrau', 'Hellgrau', '#C9CED3', '#B8D4E0', '{}', null, null, null, null, null, 2),
  ('farbe', null, 'dunkelgrau', 'Dunkelgrau', '#7C848C', '#86A6B4', '{}', null, null, null, null, null, 3),
  ('farbe', null, 'anthrazit', 'Anthrazit', '#4A5058', '#6E8F9C', '{}', null, null, null, null, null, 4),
  ('farbe', null, 'schwarz', 'Schwarz', '#25282C', '#5A7884', '{}', null, null, null, null, null, 5),
  ('lamelle', null, 'transp', 'Transparent', '#DCE6EA', null, '{}', null, null, null, null, null, 1),
  ('lamelle', null, 'grau', 'Grau', '#9AA1A8', null, '{}', null, null, null, null, null, 2),
  ('lamelle', null, 'hschwarz', 'Hellschwarz', '#3F454C', null, '{}', null, null, null, null, null, 3),
  ('lamelle', null, 'blau', 'Blau', '#4F7FA8', null, '{}', null, null, null, null, null, 4),
  ('lamelle', null, 'bronze', 'Bronze', '#8A6A4A', null, '{}', null, null, null, null, null, 5),
  ('lamelle', null, 'gruen', 'Grün', '#5F7A55', null, '{}', null, null, null, null, null, 6),
  ('belag', null, 'pp', 'PP (Beckenfarbe)', null, null, '{}', null, null, null, null, null, 1),
  ('belag', null, 'wpc', 'WPC Holzoptik', '#9B7B5C', null, '{}', null, null, null, null, null, 2),
  ('belag', null, 'stein', 'Naturstein', '#B9B2A6', null, '{}', null, null, null, null, null, 3),
  ('belag', null, 'keramik', 'Keramik', '#D7D3CC', null, '{}', null, null, null, null, null, 4),
  ('einbauteil', 'skimmer', null, 'Skimmer PP breit', null, null, '{}', null, null, null, null, null, 1),
  ('einbauteil', 'skimmer', null, 'Skimmer PP Standard', null, null, '{}', null, null, null, null, null, 2),
  ('einbauteil', 'duese', null, 'Einlaufdüse verstellbar', null, null, '{Kunststoff,Edelstahl}', null, null, null, null, null, 1),
  ('einbauteil', 'licht', null, 'EVA SubAqua XS 10 W', null, null, '{}', 'Festanschluss', 'Absprache*', '230', '10 W', null, 1),
  ('einbauteil', 'licht', null, 'EVA SubAqua MONO 25 W', null, null, '{}', 'Festanschluss', 'Absprache*', '230', '25 W', '2 Seiten', 2),
  ('einbauteil', 'licht', null, 'EVA SubAqua MONO 40 W', null, null, '{}', 'Festanschluss', 'Absprache*', '230', '50 W', '2 Seiten', 3),
  ('einbauteil', 'licht', null, 'EVA SubAqua RGBW 25 W', null, null, '{}', 'Festanschluss', 'Absprache*', '230', '25 W', '3 Seiten', 4),
  ('einbauteil', 'licht', null, 'EVA SubAqua RGBW 40 W', null, null, '{}', 'Festanschluss', 'Absprache*', '230', '50 W', '3 Seiten', 5),
  ('einbauteil', 'ablauf', null, 'PPr Flansch D110 inkl. Gitter', null, null, '{}', null, null, null, null, null, 1),
  ('einbauteil', 'gegen', null, 'EVA Stream FIT 3.0', null, null, '{}', 'Steuerung', 'Absprache*', '230', '1500 W', '3 Seiten', 1),
  ('einbauteil', 'gegen', null, 'EVA Stream FIT 4.5', null, null, '{}', 'Steuerung', 'Absprache*', '400', '2200 W', '3 Seiten', 2),
  ('einbauteil', 'gegen', null, 'EVA Stream FIT 6.5', null, null, '{}', 'Steuerung', 'Absprache*', '400', '3000 W', '3 Seiten', 3),
  ('technik', 'filter', null, 'Sandfilter Ø 600', null, null, '{}', null, null, null, null, null, 1),
  ('technik', 'filter', null, 'Glasfilter Ø 600', null, null, '{}', null, null, null, null, null, 2),
  ('technik', 'filter', null, 'Vliesfilter', null, null, '{}', 'Steckdose', 'Dauerstrom', '230', '100 W', null, 3),
  ('technik', 'pumpe', null, 'InverMaster', null, null, '{}', 'Festanschluss', 'Poolsteuerung', '230', '1200 W', null, 1),
  ('technik', 'pflege', null, 'Aqua.NET pH/Redox', null, null, '{}', 'Steckdose', 'Dauerstrom', '230', '14 VA', '1 Seite', 1),
  ('technik', 'pflege', null, 'Aqua.NET + UVC', null, null, '{}', null, null, null, null, null, 2),
  ('technik', 'pflege', null, 'DA-GEN', null, null, '{}', 'Steckdose', 'Dauerstrom', '230', '13 A', '2 Seiten', 3),
  ('technik', 'wp', null, 'Silence 30 MPXC150', null, null, '{}', 'Festanschluss', 'Dauerstrom', '230', null, '2 Seiten', 1),
  ('technik', 'wp', null, 'Silence 30 MPXC100', null, null, '{}', 'Festanschluss', 'Dauerstrom', '230', null, '2 Seiten', 2),
  ('technik', 'wp', null, 'Silence 30 MPXC190', null, null, '{}', 'Festanschluss', 'Dauerstrom', '230', null, '2 Seiten', 3),
  ('technik', 'wp', null, 'Silence 30 MPXC280-S', null, null, '{}', 'Festanschluss', 'Dauerstrom', '400', null, '2 Seiten', 4),
  ('technik', 'wp', null, 'keine', null, null, '{}', null, null, null, null, null, 9),
  ('technik', 'nachsp', null, 'automatisch', null, null, '{}', 'Festanschluss', 'Dauerstrom', '230', '200 W', '2 Seiten', 1),
  ('technik', 'nachsp', null, 'keine', null, null, '{}', null, null, null, null, null, 9)
) v
where not exists (select 1 from pool_katalog);
