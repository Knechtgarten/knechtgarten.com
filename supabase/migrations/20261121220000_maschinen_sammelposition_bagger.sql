-- Maschinen-Sammelposition «Bagger»: alle Raupenbagger und Dumper (S/M/L) erscheinen in der Offerte als eine Zeile
-- «Maschinenaufwand Bagger» (Rückmeldung Schwimmteich, Stefan 2026-11-21). Gilt für alle Formel-Vorlagen.
with sp as (
  insert into maschinen_sammelposition (name, reihenfolge)
  select 'Bagger', coalesce((select max(reihenfolge) from maschinen_sammelposition), 0) + 1
  where not exists (select 1 from maschinen_sammelposition where name = 'Bagger')
  returning id
)
insert into maschinen_sammelposition_artikel (sammelposition_id, artikel_id)
select sp.id, a.id from sp, artikel a where a.artikelnummer_knecht in ('KNECHT_000111', 'KNECHT_000112', 'KNECHT_000113', 'KNECHT_000114', 'KNECHT_000115', 'KNECHT_000116');
select sp.name, count(x.*) artikel from maschinen_sammelposition sp join maschinen_sammelposition_artikel x on x.sammelposition_id = sp.id group by sp.name;
