-- Bewässerung: Material pro Bereich statt alles in «Material Steuerung»
-- Pro Bereich (Rasen, Pflanzflächen, Hecke, Gefässe rund, Metallgefässe) ein eigener Arbeitsschritt
-- mit einem Teilschritt ohne Auswahl: seine Zeilen gelten immer und rechnen nur mit den Spalten der eigenen Tabelle.
-- In der Offerte gibt das je eine Position «Material Bewässerung …».
-- In «Steuerung» bleibt das Allgemeine (Controller, Gateway, Magnetventile, Verteiler, Druckminderer, Hilfsmaterial, Boxen).
-- Nut-Lock-Kupplungen wandern pro Zone in die Bereiche (gilt jetzt auch bei GEKA).
-- Magnetventile bleiben bei den Rohnertec-Steuerungen (GEKA braucht keine), neu als eigene Offertenposition.
begin;

-- Platz schaffen nach «Steuerung» (Reihenfolge 2)
update arbeitsschritt set reihenfolge = reihenfolge + 5
 where offertentyp_id = '96e3eee2-27f4-4161-af6f-1614afac07c9' and reihenfolge > 2;

create temp table bw_bereich (k text primary key, name text, reihenfolge int, as_id uuid default gen_random_uuid(), ts_id uuid default gen_random_uuid()) on commit drop;
insert into bw_bereich (k, name, reihenfolge) values
  ('rasen',  'Bewässerung Rasen',          3),
  ('pflanz', 'Bewässerung Pflanzflächen',  4),
  ('hecke',  'Bewässerung Hecke',          5),
  ('rund',   'Bewässerung Gefässe rund',   6),
  ('metall', 'Bewässerung Metallgefässe',  7);

insert into arbeitsschritt (id, offertentyp_id, name, reihenfolge)
  select as_id, '96e3eee2-27f4-4161-af6f-1614afac07c9', name, reihenfolge from bw_bereich;
insert into teilschritt (id, arbeitsschritt_id, name, reihenfolge)
  select ts_id, as_id, 'Material', 1 from bw_bereich;

-- Artikel aus den bisherigen Zeilen (Rohnertec SIM) übernehmen
create temp table bw_art (k text primary key, artikel_id uuid) on commit drop;
insert into bw_art select k, (select artikel_id from ressourcenzeile where id = v::uuid) from (values
  ('NUT','c80b6259-a056-4433-96d9-bc9239e979bb'), ('KLT','1f13bd8b-f86d-454f-908b-80e24863268f'), ('KLA','6708036e-435f-4337-b1d3-b28db517cb22'),
  ('SWING','2d471553-a6f3-4f8c-8699-e520637a83e7'), ('ROT','4a3b7f5f-c7c7-4ae0-9e48-df18f7d22011'), ('REGN','4eeae205-d68d-459c-852e-56ccbad2d55b'),
  ('DR25','0a596b5b-0ead-4633-a98f-30066a445ee8'), ('TECO','4be13b4b-ca3b-4f35-969d-5c77fceb9ebe'), ('LQK','7a0a067a-a1da-480d-bf4f-2e90fc3ed786'),
  ('MIKV','5b1d5354-155c-47fa-9b3e-d4751d9e09fd'), ('TORO','db60580e-9d07-4475-8ce8-42eaf000ebae'), ('MIKL','9ceba256-088c-4f12-a6d0-1be34e7d66b8'),
  ('BUEG','53cdba27-5225-4c76-b462-2bb2c163ba23'), ('NETA','c04e30e5-fdda-42df-9987-9121112ca2e5'), ('LQT','bb418bc4-2f9b-477e-bf2f-5a15280c90c7'),
  ('DR16','54d4aa03-99b5-40f9-9ac5-d05a9ccdb120'), ('OPTI','55b15487-02a2-4251-ae99-64c7dfa42cab'), ('OPTF','c8eb32c3-5f70-4f6c-b55a-7e7a6e72c6af')
) x(k, v);

-- Bausteine für die Formeln
create function pg_temp.sp(id text) returns jsonb language sql as $$ select jsonb_build_object('id', id, 'ref', 'spalte') $$;
create function pg_temp.mal(a jsonb, n numeric) returns jsonb language sql as $$ select jsonb_build_object('op', '*', 'args', jsonb_build_array(a, jsonb_build_object('lit', n))) $$;
create function pg_temp.durch(a jsonb, n numeric) returns jsonb language sql as $$ select jsonb_build_object('op', '/', 'args', jsonb_build_array(a, jsonb_build_object('lit', n))) $$;

create temp table bw_zeile (bereich text, nr int, art text, f jsonb) on commit drop;
-- Rasen: Zonen 0154d3cf, Düsen 81b6b589, Zuleitung 25 mm 26ce6c4f
insert into bw_zeile values
  ('rasen', 1, 'NUT',   pg_temp.sp('0154d3cf-0b66-4416-b7b7-4d2fd706bd48')),
  ('rasen', 2, 'KLT',   pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef')),
  ('rasen', 3, 'KLA',   pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef')),
  ('rasen', 4, 'SWING', pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef')),
  ('rasen', 5, 'ROT',   pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef')),
  ('rasen', 6, 'REGN',  pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef')),
  ('rasen', 7, 'DR25',  pg_temp.durch(pg_temp.sp('81b6b589-db29-4488-acbb-614723b67fef'), 10)),
  ('rasen', 8, 'DR25',  pg_temp.durch(pg_temp.sp('26ce6c4f-d2ca-44f6-b8ec-dabc0759b673'), 100));
-- Pflanzflächen: Zonen 636e99a5, Fläche 50865af3, 16 mm 37a03249, Optiflex 42661f5a, Fittinge 5695926b
insert into bw_zeile values
  ('pflanz', 1, 'NUT',  pg_temp.sp('636e99a5-5831-4496-b3f9-a9774540af40')),
  ('pflanz', 2, 'NETA', pg_temp.mal(pg_temp.durch(pg_temp.sp('50865af3-fc3f-464a-9ca5-b06757b69cb8'), 100), 4)),
  ('pflanz', 3, 'LQT',  pg_temp.mal(pg_temp.sp('50865af3-fc3f-464a-9ca5-b06757b69cb8'), 0.2)),
  ('pflanz', 4, 'BUEG', pg_temp.mal(pg_temp.durch(pg_temp.sp('50865af3-fc3f-464a-9ca5-b06757b69cb8'), 100), 2)),
  ('pflanz', 5, 'DR16', pg_temp.durch(pg_temp.sp('37a03249-1dbd-4bd5-8c1d-7d6984ce8495'), 50)),
  ('pflanz', 6, 'OPTI', pg_temp.sp('42661f5a-8e66-4ac9-89e6-d8236ac810c2')),
  ('pflanz', 7, 'OPTF', pg_temp.sp('5695926b-e314-4e3e-b4e8-972b064e3acd'));
-- Hecke: Zonen cbb04847, Länge 3e9f9656, 16 mm ffe08b27, Optiflex 2ad90035, Fittinge e6e880da
insert into bw_zeile values
  ('hecke', 1, 'NUT',  pg_temp.sp('cbb04847-7a61-4177-9090-c4e7260d714f')),
  ('hecke', 2, 'NETA', pg_temp.mal(pg_temp.durch(pg_temp.sp('3e9f9656-0d62-4b20-91a0-5a434913fa99'), 100), 2)),
  ('hecke', 3, 'LQT',  pg_temp.mal(pg_temp.sp('3e9f9656-0d62-4b20-91a0-5a434913fa99'), 0.2)),
  ('hecke', 4, 'BUEG', pg_temp.mal(pg_temp.durch(pg_temp.sp('3e9f9656-0d62-4b20-91a0-5a434913fa99'), 100), 4)),
  ('hecke', 5, 'DR16', pg_temp.durch(pg_temp.sp('ffe08b27-1a9b-4037-b545-8c290ec3c85c'), 50)),
  ('hecke', 6, 'OPTI', pg_temp.sp('2ad90035-0a84-4bfb-b399-c2f6ac7de137')),
  ('hecke', 7, 'OPTF', pg_temp.sp('e6e880da-6a99-4eab-bf57-423df559fb7a'));
-- Gefässe rund (Zonen c357772c, Gefässe a09d08f0, 16 mm 2f8ec0b8, Optiflex b50605d7, Fittinge afc2dec0)
-- und Metallgefässe (Zonen 872ea3aa, Gefässe 60dd939f, 16 mm 60e54f89, Optiflex 0e3c3884, Fittinge e2a3e2ce): gleiche Zeilen
insert into bw_zeile
  select b, n, art, f from (values ('rund','c357772c-6b13-4132-b402-1c07cb473710','a09d08f0-932b-482e-8728-0a2736ced3c2','2f8ec0b8-9c8b-4c5a-8a98-7f3172cbcb08','b50605d7-7789-41c1-a2d2-c7eaaa312f71','afc2dec0-a632-4aa2-9fca-c5650d970692'),
                               ('metall','872ea3aa-2d61-456d-95ca-958edb85585b','60dd939f-e47c-478c-8f2b-6073a7831a96','60e54f89-f6c2-45b5-8be1-74aaaf08865d','0e3c3884-43ba-4e32-b734-f39a17d42664','e2a3e2ce-a955-44ab-9ac8-62549a29d717')) g(b, zo, ge, l16, op, ofi),
  lateral (values
    (1,  'NUT',  pg_temp.sp(zo)),
    (2,  'TECO', pg_temp.mal(pg_temp.sp(ge), 0.3)),
    (3,  'LQK',  pg_temp.sp(ge)),
    (4,  'MIKV', pg_temp.sp(ge)),
    (5,  'TORO', pg_temp.mal(pg_temp.sp(ge), 2)),
    (6,  'MIKL', pg_temp.mal(pg_temp.sp(ge), 0.25)),
    (7,  'BUEG', pg_temp.mal(pg_temp.durch(pg_temp.sp(ge), 100), 4)),
    (8,  'DR16', pg_temp.durch(pg_temp.sp(l16), 50)),
    (9,  'OPTI', pg_temp.sp(op)),
    (10, 'OPTF', pg_temp.sp(ofi))) zz(n, art, f);

insert into ressourcenzeile (teilschritt_id, option_id, kategorie, artikel_id, menge_formel_modus, menge_formel_baukasten_ausdruck, menge_ausdruck, reihenfolge)
  select b.ts_id, null, 'material', a.artikel_id, 'baukasten', z.f, z.f, z.nr
    from bw_zeile z join bw_bereich b on b.k = z.bereich join bw_art a on a.k = z.art;

-- Alte Bereichs-Zeilen und Nut Lock aus den Steuerungs-Optionen (SIM, WLAN, GEKA) entfernen
delete from ressourcenzeile r
 using auswahloption o, auswahlfeld f
 where o.id = r.option_id and f.id = o.auswahlfeld_id and f.teilschritt_id = 'ac594222-f10f-4aaa-8cae-0ee3e9e126ff' and r.kategorie = 'material'
   and (r.menge_formel_baukasten_ausdruck::text ~ '(81b6b589|26ce6c4f|3e9f9656|50865af3|02426c53|a4684e78|5e637817|b46eb16f)'
        or r.artikel_id = (select artikel_id from bw_art where k = 'NUT'));

-- Magnetventile (Rohnertec) als eigene Offertenposition, wie Controller, Gateway und Sensor
update ressourcenzeile r set ist_eigene_offertenposition = true
  from auswahloption o, auswahlfeld f, artikel a
 where o.id = r.option_id and f.id = o.auswahlfeld_id and f.teilschritt_id = 'ac594222-f10f-4aaa-8cae-0ee3e9e126ff'
   and a.id = r.artikel_id and a.bezeichnung ilike 'Rain Bird Magnetventil%';

commit;
