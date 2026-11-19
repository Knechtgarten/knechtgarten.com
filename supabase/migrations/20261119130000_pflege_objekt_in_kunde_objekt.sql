-- Pflege-Objekte und Kunden-Objekte zusammenführen (Stefan 2026-11-19):
-- Es gibt nur noch die Tabelle kunde_objekt. Ein Objekt, das in Kontakte, im Offertentool oder im
-- Pflegetool erfasst wird, ist überall dasselbe.
-- pflege_objekt bleibt als Ansicht mit denselben Spalten (+ name), damit Pflegetool, Pflege-Handy,
-- Kontakte-Karte und die Geocode-Funktion unverändert lesen und schreiben können.
-- Alte Tabelle bleibt als pflege_objekt_alt (Sicherung).

-- 1) Pflege-Spalten in kunde_objekt
alter table kunde_objekt
  add column if not exists region_id uuid references pflege_region(id) on delete set null,
  add column if not exists lat double precision,
  add column if not exists lon double precision,
  add column if not exists geo_adresse text,
  add column if not exists geo_ok boolean;

-- 2) Daten übernehmen, gleiche IDs (Kategorien, Fotos, Dokumente zeigen weiter auf dieselbe ID)
insert into kunde_objekt (id, kunde_id, strasse, plz, ort, notiz, reihenfolge, erstellt_am, erstellt_von, region_id, lat, lon, geo_adresse, geo_ok)
select id, kunde_id, strasse, plz, ort, notiz, coalesce(reihenfolge, 0), erstellt_am, null, region_id, lat, lon, geo_adresse, geo_ok
from pflege_objekt
on conflict (id) do nothing;

-- 3) Fremdschlüssel der Pflege-Tabellen auf kunde_objekt umhängen (wie bisher: Objekt weg = Pflegedaten des Objekts weg)
alter table pflege_kunde_kategorie drop constraint if exists pflege_kunde_kategorie_objekt_id_fkey,
  add constraint pflege_kunde_kategorie_objekt_id_fkey foreign key (objekt_id) references kunde_objekt(id) on delete cascade;
alter table pflege_foto drop constraint if exists pflege_foto_objekt_id_fkey,
  add constraint pflege_foto_objekt_id_fkey foreign key (objekt_id) references kunde_objekt(id) on delete cascade;
alter table pflege_dokument drop constraint if exists pflege_dokument_objekt_id_fkey,
  add constraint pflege_dokument_objekt_id_fkey foreign key (objekt_id) references kunde_objekt(id) on delete cascade;

-- 4) alte Tabelle sichern, Ansicht mit gleichem Namen (automatisch beschreibbar, Rechte von kunde_objekt)
alter table pflege_objekt rename to pflege_objekt_alt;
revoke all on pflege_objekt_alt from anon, authenticated;
create view pflege_objekt with (security_invoker = true) as
  select id, kunde_id, name, strasse, plz, ort, notiz, reihenfolge, erstellt_am, region_id, lat, lon, geo_adresse, geo_ok
  from kunde_objekt;
grant select, insert, update, delete on pflege_objekt to authenticated;
grant select, insert, update, delete on pflege_objekt to service_role;
