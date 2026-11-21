-- Bewässerung: Verlegezeit in den Tabellen (Stefan 2026-11-21), Team Servicetechniker + Gartenarbeiter (je gleich viele Std.).
-- Pro Person:  Rasen 0.75 Std./Düse + 1 Std./Zone + 0.05 Std./m Zuleitung 25 mm
--              Pflanzflächen 0.05 Std./m² + 0.75 Std./Zone + 0.03 Std./m Zuleitung 16 mm + 0.05 Std./m Optiflex
--              Hecke 0.04 Std./m Hecke + Zone/Zuleitungen wie Pflanzflächen
--              Gefässe rund 0.5 Std./Gefäss, Metallgefässe 0.75 Std./Gefäss + Zone/Zuleitungen wie Pflanzflächen
-- Die bisherige Verlegezeit in der Steuerung (Servicetechniker 1 Std./Düse, 0.05 Std./m², 0.05 Std./m Hecke) wird entfernt.

create or replace function pg_temp.summe(teile jsonb) returns jsonb language sql immutable as $$
  -- teile = [[spalte_id, faktor], …] → {op:'+', args:[{op:'*', args:[spalte, lit]}, …]}
  select jsonb_build_object('op', '+', 'args', jsonb_agg(jsonb_build_object('op', '*', 'args',
    jsonb_build_array(jsonb_build_object('id', t->>0, 'ref', 'spalte'), jsonb_build_object('lit', (t->>1)::numeric)))))
  from jsonb_array_elements(teile) t
$$;

with z(teil, teile) as (values
  ('2c2de4b8-612a-4fee-9768-d212683cbbda', '[["81b6b589-db29-4488-acbb-614723b67fef", 0.75], ["0154d3cf-0b66-4416-b7b7-4d2fd706bd48", 1], ["26ce6c4f-d2ca-44f6-b8ec-dabc0759b673", 0.05]]'),
  ('80c5f3a4-a0e4-40e9-8d4f-1e800d691044', '[["50865af3-fc3f-464a-9ca5-b06757b69cb8", 0.05], ["636e99a5-5831-4496-b3f9-a9774540af40", 0.75], ["37a03249-1dbd-4bd5-8c1d-7d6984ce8495", 0.03], ["42661f5a-8e66-4ac9-89e6-d8236ac810c2", 0.05]]'),
  ('da725d3e-b8b0-4ec8-bcbc-b20b990060a5', '[["3e9f9656-0d62-4b20-91a0-5a434913fa99", 0.04], ["cbb04847-7a61-4177-9090-c4e7260d714f", 0.75], ["ffe08b27-1a9b-4037-b545-8c290ec3c85c", 0.03], ["2ad90035-0a84-4bfb-b399-c2f6ac7de137", 0.05]]'),
  ('37287a73-8a81-44ce-8749-5a337e62565f', '[["a09d08f0-932b-482e-8728-0a2736ced3c2", 0.5], ["c357772c-6b13-4132-b402-1c07cb473710", 0.75], ["2f8ec0b8-9c8b-4c5a-8a98-7f3172cbcb08", 0.03], ["b50605d7-7789-41c1-a2d2-c7eaaa312f71", 0.05]]'),
  ('26ab7c73-b54f-4fdc-af24-9f2865c985c8', '[["60dd939f-e47c-478c-8f2b-6073a7831a96", 0.75], ["872ea3aa-2d61-456d-95ca-958edb85585b", 0.75], ["60e54f89-f6c2-45b5-8be1-74aaaf08865d", 0.03], ["0e3c3884-43ba-4e32-b734-f39a17d42664", 0.05]]')
), p(artikel, rf) as (values ('b923e710-f074-4b8e-8829-b31cea82708b'::uuid, 0), ('794454dd-c8a4-457a-ab66-b69fa4f6ea81'::uuid, 1))
insert into ressourcenzeile (teilschritt_id, kategorie, artikel_id, menge_ausdruck, menge_formel_baukasten_ausdruck, menge_formel_modus, notiz,
  zugang_stufe1, zugang_stufe2, zugang_stufe3, zugang_stufe4, reihenfolge)
select z.teil::uuid, 'personal', p.artikel, pg_temp.summe(z.teile::jsonb), pg_temp.summe(z.teile::jsonb), 'baukasten', 'Verlegezeit (Team Servicetechniker + Gartenarbeiter)',
  1, 1, 1, 1, p.rf - 10
from z cross join p
where not exists (select 1 from ressourcenzeile r where r.teilschritt_id = z.teil::uuid and r.kategorie = 'personal' and r.artikel_id = p.artikel);

-- Verlegezeit aus der Steuerung entfernen (jetzt in den Tabellen)
delete from ressourcenzeile where id in (
  '24111743-821a-4db9-b0b5-a0b68a705841', '6c5d75bd-4812-4736-b420-9a81582f7ac2', 'f2145b9d-e4db-40a1-b4f5-06108d1cf6d6',
  '780d1cb6-e965-49c9-b242-ec2d7a7c807b', 'a44fcf5a-ea93-415e-8326-009f0e43da74', '5d75e0d7-f115-4cae-a22c-f5a24636a4cb',
  '9529c520-2690-47bf-8486-260fca7d7286', 'bc7c5574-11ed-4773-b00b-c4a23c8f1c28', '7f2e5028-3a1d-44f5-8a15-15b405f0f530');
