-- Tagesrechner (Tagessatz): Polier / Vorarbeiter und Gartenarbeiter mit je 9 Std. pro Tag in jedem Teilschritt (Nutzerentscheid 2026-10-28).
-- Seit dem Umbau vom 2026-07-22 gibt es keine Personal-Automatik mehr, die Vorlagen hatten aber keine Personalzeilen -> 0 Std. Personal und dadurch
-- auch 0 Lieferwagenfahrzeit (die haengt an den Personalstunden). Personal steht ganz oben im Teilschritt.
insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, tagesleistung_menge, reihenfolge, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4)
select ts.id, 'personal', p.artikel_id, 9, p.reihenfolge, 1, 1, 1, 1
  from teilschritt ts
  join arbeitsschritt ar on ar.id = ts.arbeitsschritt_id
  join offertentyp ot on ot.id = ar.offertentyp_id and ot.berechnungsmodell = 'tagessatz'
 cross join (values ('006e6793-37de-46e2-8a0b-45a0065313db'::uuid, -2), ('794454dd-c8a4-457a-ab66-b69fa4f6ea81'::uuid, -1)) as p(artikel_id, reihenfolge)
 where not exists (select 1 from ressourcenzeile rz where rz.teilschritt_id = ts.id and rz.artikel_id = p.artikel_id);
