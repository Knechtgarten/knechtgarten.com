-- Startauswahl im Tool-Menü für alle mit Merkmal «Projektleiter»: oben Offertentool, Artikelstamm, Kontakte,
-- Einsatzplaner, Pendenzen; alle anderen Tools unten bei «Weitere Tools». Häufigkeit (aufrufe) bleibt. Jeder kann danach selber umstellen.
with pl as (
  select bm.benutzer_id from benutzer_merkmal bm join merkmal m on m.id = bm.merkmal_id where m.schluessel = 'projektleiter'
), tools(app_key, oben, sortierung) as (values
  ('offerten', true, 10), ('artikel', true, 20), ('kunden', true, 30), ('plan', true, 40), ('pend', true, 50),
  ('projekte', false, 10), ('wissen', false, 20), ('masch', false, 30), ('werkzeuge', false, 40), ('pool', false, 50),
  ('bew', false, 60), ('cad', false, 70), ('doku', false, 80)
)
insert into tool_menue (benutzer_id, app_key, sortierung, an)
select pl.benutzer_id, t.app_key, t.sortierung, t.oben from pl cross join tools t
on conflict (benutzer_id, app_key) do update set an = excluded.an, sortierung = excluded.sortierung;

select b.anzeigename, string_agg(tm.app_key, ', ' order by tm.sortierung) filter (where tm.an) as meine_tools
from tool_menue tm join benutzer b on b.id = tm.benutzer_id
where tm.benutzer_id in (select bm.benutzer_id from benutzer_merkmal bm join merkmal m on m.id = bm.merkmal_id where m.schluessel = 'projektleiter')
group by b.anzeigename order by 1;
