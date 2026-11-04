-- Pooloptionen: neuer Arbeitsschritt «Poolreinigung» – automatische Reinigung mit Poolroboter.
-- Aufbau wie «Duschen»: Teilschritt → Auswahlfeld → eine Option pro Roboter (Einfachauswahl),
-- je 1 Std. Polier für Inbetriebnahme und Instruktion + 1 Stk. Roboter (Aquasolar-Artikel, Foto als Hinweisbild).
with a as (
  insert into arbeitsschritt (offertentyp_id, name, reihenfolge)
  values ('5347bac1-9562-469d-b4cd-fc9885a571f7', 'Poolreinigung',
          (select coalesce(max(reihenfolge), 0) + 1 from arbeitsschritt where offertentyp_id = '5347bac1-9562-469d-b4cd-fc9885a571f7'))
  returning id
), t as (
  insert into teilschritt (arbeitsschritt_id, name, reihenfolge) select id, 'Automatische Reinigung', 1 from a returning id
), f as (
  insert into auswahlfeld (teilschritt_id, name, reihenfolge) select id, 'Poolroboter', 1 from t returning id
), o as (
  insert into auswahloption (auswahlfeld_id, name, reihenfolge, beschreibung, hinweistext, hinweisbild_url, ist_standard, mengenoption, mengenoption_einheit, mehrfachauswahl, ist_eigene_offertenposition)
  select f.id, v.name, v.rf, v.beschr, v.hinweis, (select foto_url from artikel where id = v.artikel), false, false, 'Stk.', false, true
  from f, (values
    ('Dolphin EON 120d (Akku)', 1, 'Poolroboter Dolphin EON 120d mit PVC-Bürsten und Ladegerät liefern, in Betrieb nehmen und Bedienung instruieren.',
     'Akku-Roboter (kabellos), PVC-Bürsten, mit Ladegerät.', 'f29fb984-0928-4f18-a1e4-600cf639d3a2'::uuid),
    ('Dolphin S3000 (mit Kabel)', 2, 'Poolroboter Dolphin S3000 mit Kombibürsten, Caddy und Schutzhülle liefern, in Betrieb nehmen und Bedienung instruieren.',
     'Roboter mit Kabel, Kombibürsten, mit Caddy und Schutzhülle, für alle Beckentypen.', '94b729ae-3da3-4eb4-a4cb-0889299a9cdb'::uuid)
  ) as v(name, rf, beschr, hinweis, artikel)
  returning id, name
)
insert into ressourcenzeile (option_id, kategorie, artikel_id, menge_ausdruck, notiz, zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge, menge_formel_modus)
select o.id, z.kat, z.artikel, z.menge::jsonb, z.notiz, 1, 1, 1, 1, z.rf, 'baukasten'
from o join (values
  ('Dolphin EON 120d (Akku)',   'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a'::uuid, '{"lit": 1, "_einheit": "Std."}', 'Inbetriebnahme und Instruktion', 1),
  ('Dolphin EON 120d (Akku)',   'material', 'f29fb984-0928-4f18-a1e4-600cf639d3a2'::uuid, '{"lit": 1, "_einheit": "Stk."}', null, 2),
  ('Dolphin S3000 (mit Kabel)', 'personal', '8fa14723-4de8-4395-a50a-4f72c11e9a7a'::uuid, '{"lit": 1, "_einheit": "Std."}', 'Inbetriebnahme und Instruktion', 1),
  ('Dolphin S3000 (mit Kabel)', 'material', '94b729ae-3da3-4eb4-a4cb-0889299a9cdb'::uuid, '{"lit": 1, "_einheit": "Stk."}', null, 2)
) as z(opt, kat, artikel, menge, notiz, rf) on z.opt = o.name;
