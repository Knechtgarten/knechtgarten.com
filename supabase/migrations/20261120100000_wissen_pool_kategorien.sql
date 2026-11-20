-- Nachschlagewerk: Pool-Kategorien (Entscheid Stefan 2026-11-20)
--   Produkte › Poolpflegemittel, Produkte › Poolkomponenten (mit Elektro-Feldern für das spätere Elektriker-Dokument
--   aus dem Pool-Konfigurator), Wissen › Pool & Wasser. Thema quer durch alles = Stichwort «Pool».
--   (Es gibt schon eine leere Kategorie «Pooltechnik» bei Maschinen & Geräte mit Feldern pro Stück – bleibt unverändert.)
insert into wissen_feld (name, art, einheit, optionen)
select v.name, v.art, v.einheit, v.optionen from (values
  ('Spannung', 'auswahl', null, array['230 V', '400 V']),
  ('Absicherung', 'zahl', 'A', null::text[]),
  ('Stromaufnahme', 'zahl', 'A', null::text[]),
  ('Elektroanschluss', 'auswahl', null, array['Stecker', 'Festanschluss']),
  ('Dosierung', 'text', null, null::text[])
) v(name, art, einheit, optionen)
where not exists (select 1 from wissen_feld f where f.name = v.name);

with f as (select name, id from wissen_feld)
insert into wissen_kategorie (name, art, sortierung, bausteine, felder)
select v.name, v.art, (select max(sortierung) from wissen_kategorie) + v.n * 10, v.bausteine::jsonb, v.felder
from (values
  ('Poolpflegemittel', 'produkt', 1,
   '[{"k":"notizen","m":"offen"},{"k":"steck","m":"offen"},{"k":"sicher","m":"zu"},{"k":"kontakte","m":"zu"},{"k":"docs","m":"zu"}]',
   (select jsonb_agg(jsonb_build_object('f', id, 's', false) order by array_position(array['Hersteller / Modell','Gebindegrösse','Dosierung'], name)) from f where name in ('Hersteller / Modell','Gebindegrösse','Dosierung'))),
  ('Poolkomponenten', 'produkt', 2,
   '[{"k":"notizen","m":"offen"},{"k":"steck","m":"offen"},{"k":"anw","m":"zu"},{"k":"kontakte","m":"zu"},{"k":"docs","m":"zu"}]',
   (select jsonb_agg(jsonb_build_object('f', id, 's', false) order by array_position(array['Hersteller / Modell','Leistung','Spannung','Absicherung','Stromaufnahme','Elektroanschluss'], name)) from f where name in ('Hersteller / Modell','Leistung','Spannung','Absicherung','Stromaufnahme','Elektroanschluss'))),
  ('Pool & Wasser', 'wissen', 3,
   '[{"k":"anw","m":"offen"},{"k":"notizen","m":"offen"},{"k":"docs","m":"zu"}]', '[]'::jsonb)
) v(name, art, n, bausteine, felder)
where not exists (select 1 from wissen_kategorie k where k.name = v.name);

select name, art, jsonb_array_length(felder) felder from wissen_kategorie where name in ('Poolpflegemittel','Poolkomponenten','Pool & Wasser');
