-- ============================================================================
-- Wissen & Geräte: Merkmal-Vorschläge pro Kategorie (kategorie_id null = für alle)
-- und mit Ziel: technisch = Technische Daten (gleich für alle Exemplare),
-- exemplar = Angaben des Exemplars, verwaltung = Verwaltung (nur Büro).
-- ============================================================================
begin;

alter table wissen_merkmal add column if not exists kategorie_id uuid null references wissen_kategorie(id) on delete cascade;
alter table wissen_merkmal add column if not exists ziel text not null default 'technisch';
alter table wissen_merkmal drop constraint if exists wissen_merkmal_ziel_check;
alter table wissen_merkmal add constraint wissen_merkmal_ziel_check check (ziel in ('technisch', 'exemplar', 'verwaltung'));
alter table wissen_merkmal drop constraint if exists wissen_merkmal_name_key;
create unique index if not exists wissen_merkmal_name_kat_idx on wissen_merkmal (name, coalesce(kategorie_id, '00000000-0000-0000-0000-000000000000'::uuid));

-- Bestehende 15 Vorschläge neu zuordnen und je Kategorie ergänzen
delete from wissen_merkmal;
insert into wissen_merkmal (name, kategorie_id, ziel, sortierung)
select v.name, k.id, v.ziel, v.sort
from (values
  ('Hersteller / Modell', null, 'technisch', 10),
  ('Anschaffungsjahr', null, 'exemplar', 20),
  ('Seriennummer', null, 'exemplar', 30),
  ('Kaufpreis', null, 'verwaltung', 40),

  ('Gewicht', 'Maschinen & Fahrzeuge', 'technisch', 10),
  ('Breite', 'Maschinen & Fahrzeuge', 'technisch', 20),
  ('Höhe', 'Maschinen & Fahrzeuge', 'technisch', 30),
  ('Länge', 'Maschinen & Fahrzeuge', 'technisch', 40),
  ('Leistung', 'Maschinen & Fahrzeuge', 'technisch', 50),
  ('Treibstoff', 'Maschinen & Fahrzeuge', 'technisch', 60),
  ('Nutzlast', 'Maschinen & Fahrzeuge', 'technisch', 70),
  ('Anhängelast', 'Maschinen & Fahrzeuge', 'technisch', 80),
  ('Kontrollschild', 'Maschinen & Fahrzeuge', 'exemplar', 90),
  ('Fahrzeugprüfung', 'Maschinen & Fahrzeuge', 'exemplar', 100),
  ('Versicherung / LSVA', 'Maschinen & Fahrzeuge', 'verwaltung', 110),
  ('Kaskoschutz', 'Maschinen & Fahrzeuge', 'verwaltung', 120),
  ('Selbstbehalt', 'Maschinen & Fahrzeuge', 'verwaltung', 130),

  ('Gewicht', 'Geräte & Werkzeug', 'technisch', 10),
  ('Leistung', 'Geräte & Werkzeug', 'technisch', 20),
  ('Arbeitsbreite', 'Geräte & Werkzeug', 'technisch', 30),
  ('Akku', 'Geräte & Werkzeug', 'technisch', 40),
  ('Treibstoff', 'Geräte & Werkzeug', 'technisch', 50),

  ('Verarbeitungszeit', 'Kleber & Dichtstoffe', 'technisch', 10),
  ('Aushärtezeit', 'Kleber & Dichtstoffe', 'technisch', 20),
  ('Temperaturbereich', 'Kleber & Dichtstoffe', 'technisch', 30),
  ('Geeignet für', 'Kleber & Dichtstoffe', 'technisch', 40),
  ('Gebindegrösse', 'Kleber & Dichtstoffe', 'technisch', 50)
) v(name, kat, ziel, sort)
left join wissen_kategorie k on k.name = v.kat
where v.kat is null or k.id is not null;

commit;
