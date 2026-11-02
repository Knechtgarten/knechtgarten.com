-- Nachschlagewerk: Kategorie «Spritzmittel» mit Gebrauchsanleitung und Sicherheitsdatenblatt pro Mittel aus werkzeug_spritzmittel.
-- PDFs liegen als Kopie im Bucket wissen-dateien (<eintrag_id>/<datei_id>.pdf), Original-URLs zusätzlich als Link.
alter table werkzeug_spritzmittel add column if not exists wissen_eintrag_id uuid references wissen_eintrag(id) on delete set null;
insert into wissen_kategorie (id, name, art, sortierung, felder, bausteine)
select 'e274a912-bdb1-4446-9d58-40b13d02c441', 'Spritzmittel', 'produkt', 95, felder,
  '[{"k":"docs","m":"offen"},{"k":"sicher","m":"zu"},{"k":"anw","m":"zu"},{"k":"notizen","m":"offen"},{"k":"steck","m":"offen"},{"k":"kontakte","m":"zu"}]'::jsonb
from wissen_kategorie where name = 'Chemikalien';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '743821e6-d684-4856-b718-6d138322a6ee', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/DE/SDB_Airone_785_de.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '03229ea1-11b1-4109-bbb8-c116b716e373';
update werkzeug_spritzmittel set wissen_eintrag_id = '743821e6-d684-4856-b718-6d138322a6ee' where id = '03229ea1-11b1-4109-bbb8-c116b716e373';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '1d2fffec-5f91-4e8e-8b79-31c68e8afa64', '743821e6-d684-4856-b718-6d138322a6ee', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '743821e6-d684-4856-b718-6d138322a6ee/1d2fffec-5f91-4e8e-8b79-31c68e8afa64.pdf', 90809, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '03229ea1-11b1-4109-bbb8-c116b716e373';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '859a0b66-1686-4964-9f51-30584c5a4f47', '743821e6-d684-4856-b718-6d138322a6ee', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '743821e6-d684-4856-b718-6d138322a6ee/859a0b66-1686-4964-9f51-30584c5a4f47.pdf', 533338, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '03229ea1-11b1-4109-bbb8-c116b716e373';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '0c60a814-bc76-42de-ac10-458e2a49fed9', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '5656f3a3-c9b0-4a0d-92c1-836792238f09';
update werkzeug_spritzmittel set wissen_eintrag_id = '0c60a814-bc76-42de-ac10-458e2a49fed9' where id = '5656f3a3-c9b0-4a0d-92c1-836792238f09';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'fb62fcb9-3724-4918-8479-f691c3cf7ead', '0c60a814-bc76-42de-ac10-458e2a49fed9', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '0c60a814-bc76-42de-ac10-458e2a49fed9/fb62fcb9-3724-4918-8479-f691c3cf7ead.pdf', 663975, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '5656f3a3-c9b0-4a0d-92c1-836792238f09';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '1e779c44-7227-47cf-921e-c9797f2a147d', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/Alte-DE/Hochgeladen%20am%2002.02.23%20Deutsch/Delfin%20Sicherheitsdatenblatt%202023-01.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = 'dc5e79d9-1f19-4312-8789-ccfb93a42eab';
update werkzeug_spritzmittel set wissen_eintrag_id = '1e779c44-7227-47cf-921e-c9797f2a147d' where id = 'dc5e79d9-1f19-4312-8789-ccfb93a42eab';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '7029da3c-a9e2-4cc4-b8f2-d1dbff96b49b', '1e779c44-7227-47cf-921e-c9797f2a147d', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '1e779c44-7227-47cf-921e-c9797f2a147d/7029da3c-a9e2-4cc4-b8f2-d1dbff96b49b.pdf', 89189, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = 'dc5e79d9-1f19-4312-8789-ccfb93a42eab';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'c828b478-8729-4ce6-b733-ceb41986bfb8', '1e779c44-7227-47cf-921e-c9797f2a147d', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '1e779c44-7227-47cf-921e-c9797f2a147d/c828b478-8729-4ce6-b733-ceb41986bfb8.pdf', 192313, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = 'dc5e79d9-1f19-4312-8789-ccfb93a42eab';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '4b142e7f-fd78-48be-8901-cd451b0f78d0', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/DE/NeemAzal%20TS_Sicherheitsdatenblatt.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '821894cd-c2b7-497d-9860-e519edd958b4';
update werkzeug_spritzmittel set wissen_eintrag_id = '4b142e7f-fd78-48be-8901-cd451b0f78d0' where id = '821894cd-c2b7-497d-9860-e519edd958b4';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '6593ec05-6c0b-4cd6-b523-cc723c6d9640', '4b142e7f-fd78-48be-8901-cd451b0f78d0', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '4b142e7f-fd78-48be-8901-cd451b0f78d0/6593ec05-6c0b-4cd6-b523-cc723c6d9640.pdf', 98602, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '821894cd-c2b7-497d-9860-e519edd958b4';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '06e7fe78-a439-4039-9a8e-7710aade766a', '4b142e7f-fd78-48be-8901-cd451b0f78d0', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '4b142e7f-fd78-48be-8901-cd451b0f78d0/06e7fe78-a439-4039-9a8e-7710aade766a.pdf', 224191, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '821894cd-c2b7-497d-9860-e519edd958b4';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '34efa688-b9db-4b4a-ae96-570e0ab4a198', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/Alte-DE/Netzschwefel%20Stulln%20Sicherheitsdatenblatt%202023-02.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = 'eadd4d01-642b-47f8-bd9b-4d91e758ab68';
update werkzeug_spritzmittel set wissen_eintrag_id = '34efa688-b9db-4b4a-ae96-570e0ab4a198' where id = 'eadd4d01-642b-47f8-bd9b-4d91e758ab68';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'b6b582a0-c370-454c-9dff-872ca18879db', '34efa688-b9db-4b4a-ae96-570e0ab4a198', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '34efa688-b9db-4b4a-ae96-570e0ab4a198/b6b582a0-c370-454c-9dff-872ca18879db.pdf', 74180, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = 'eadd4d01-642b-47f8-bd9b-4d91e758ab68';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '60483b94-025b-4965-8876-5babd6ea18b0', '34efa688-b9db-4b4a-ae96-570e0ab4a198', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '34efa688-b9db-4b4a-ae96-570e0ab4a198/60483b94-025b-4965-8876-5babd6ea18b0.pdf', 203208, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = 'eadd4d01-642b-47f8-bd9b-4d91e758ab68';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select 'df5b9844-9c79-4f86-889f-ed2108f96965', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/Alte-DE/Hochgeladen%20am%2007.12.23%20Deutsch/Promanal%20Neu%20Sicherheitsdatenblatt%202023-07.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '5d4f0a97-3576-49a9-8533-a7e5802e49c0';
update werkzeug_spritzmittel set wissen_eintrag_id = 'df5b9844-9c79-4f86-889f-ed2108f96965' where id = '5d4f0a97-3576-49a9-8533-a7e5802e49c0';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '4e8ae6d4-97cc-41fc-b3d8-e3e9f7bb1602', 'df5b9844-9c79-4f86-889f-ed2108f96965', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', 'df5b9844-9c79-4f86-889f-ed2108f96965/4e8ae6d4-97cc-41fc-b3d8-e3e9f7bb1602.pdf', 51805, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '5d4f0a97-3576-49a9-8533-a7e5802e49c0';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'f939bdf4-b2dc-44d9-b869-fd1d145d5e09', 'df5b9844-9c79-4f86-889f-ed2108f96965', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', 'df5b9844-9c79-4f86-889f-ed2108f96965/f939bdf4-b2dc-44d9-b869-fd1d145d5e09.pdf', 134263, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '5d4f0a97-3576-49a9-8533-a7e5802e49c0';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '12bf8546-6ada-443a-bcf3-33ca16e92d3c', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/DE/SDB_RhizoSol_116_de.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '9b36a5a6-a051-4618-942b-6916d823a02c';
update werkzeug_spritzmittel set wissen_eintrag_id = '12bf8546-6ada-443a-bcf3-33ca16e92d3c' where id = '9b36a5a6-a051-4618-942b-6916d823a02c';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '064b41d7-9598-4564-ba95-9c56747e98bd', '12bf8546-6ada-443a-bcf3-33ca16e92d3c', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '12bf8546-6ada-443a-bcf3-33ca16e92d3c/064b41d7-9598-4564-ba95-9c56747e98bd.pdf', 55632, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '9b36a5a6-a051-4618-942b-6916d823a02c';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '300622ef-1a0a-4208-8901-70dfc602030e', '12bf8546-6ada-443a-bcf3-33ca16e92d3c', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '12bf8546-6ada-443a-bcf3-33ca16e92d3c/300622ef-1a0a-4208-8901-70dfc602030e.pdf', 390407, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '9b36a5a6-a051-4618-942b-6916d823a02c';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select 'dffb4935-b6fa-4dc6-bde2-d98fefaab633', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '7a509d57-dccb-47ae-a9fd-a1ed8a0b102f';
update werkzeug_spritzmittel set wissen_eintrag_id = 'dffb4935-b6fa-4dc6-bde2-d98fefaab633' where id = '7a509d57-dccb-47ae-a9fd-a1ed8a0b102f';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '5b11bdc2-f191-4953-b228-57fc2633b10c', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = 'da62a910-85a6-43e8-ac77-9a5a6d9d5986';
update werkzeug_spritzmittel set wissen_eintrag_id = '5b11bdc2-f191-4953-b228-57fc2633b10c' where id = 'da62a910-85a6-43e8-ac77-9a5a6d9d5986';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '1996f9e5-f6a4-4b3b-ba9e-9e7180414c1d', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '8565c544-e3e0-4261-974f-192da7590daa';
update werkzeug_spritzmittel set wissen_eintrag_id = '1996f9e5-f6a4-4b3b-ba9e-9e7180414c1d' where id = '8565c544-e3e0-4261-974f-192da7590daa';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'c58393c4-d020-42c6-bdb2-a45e788ad883', '1996f9e5-f6a4-4b3b-ba9e-9e7180414c1d', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '1996f9e5-f6a4-4b3b-ba9e-9e7180414c1d/c58393c4-d020-42c6-bdb2-a45e788ad883.pdf', 46983, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '8565c544-e3e0-4261-974f-192da7590daa';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '96bcf8ef-29cd-4bbc-9404-1260fca10f7d', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle), jsonb_build_object('titel', 'Sicherheitsdatenblatt (Original)', 'url', 'https://www.biocontrol.ch/ABCS/Dokumente/Sicherheitsdatenbl%C3%A4tter/DE/SDB_Weiss%C3%B6l_S_289_de.pdf')) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '62b8cb85-a8d6-4057-9912-61a37e7890ff';
update werkzeug_spritzmittel set wissen_eintrag_id = '96bcf8ef-29cd-4bbc-9404-1260fca10f7d' where id = '62b8cb85-a8d6-4057-9912-61a37e7890ff';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '61a01c22-d16b-4b62-8096-766969da1217', '96bcf8ef-29cd-4bbc-9404-1260fca10f7d', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '96bcf8ef-29cd-4bbc-9404-1260fca10f7d/61a01c22-d16b-4b62-8096-766969da1217.pdf', 43248, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '62b8cb85-a8d6-4057-9912-61a37e7890ff';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select '22b69798-ffba-4829-92b5-758b7e7fba55', '96bcf8ef-29cd-4bbc-9404-1260fca10f7d', 'dokument', 'pdf', 'Sicherheitsdatenblatt ' || s.name || '.pdf', 'Sicherheitsdatenblatt', '96bcf8ef-29cd-4bbc-9404-1260fca10f7d/22b69798-ffba-4829-92b5-758b7e7fba55.pdf', 321142, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = '62b8cb85-a8d6-4057-9912-61a37e7890ff';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '7b27ab3f-125c-4b53-8991-a5e0bdcbbe02', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = '21fcc513-2b4a-41d0-afc6-b9534cdf7507';
update werkzeug_spritzmittel set wissen_eintrag_id = '7b27ab3f-125c-4b53-8991-a5e0bdcbbe02' where id = '21fcc513-2b4a-41d0-afc6-b9534cdf7507';
insert into wissen_eintrag (id, typ, titel, untertitel, kategorie_id, links, erstellt_von)
select '43332cdb-7efc-4fcb-a90f-9a7ffc94141c', 'produkt', s.name, nullif(concat_ws(' · ', s.hersteller, s.art), ''), 'e274a912-bdb1-4446-9d58-40b13d02c441',
  case when s.quelle is null then '[]'::jsonb else jsonb_build_array(jsonb_build_object('titel', case when s.quelle like '%psm.admin.ch%' then 'Pflanzenschutzmittelverzeichnis (BLW)' else 'Gebrauchsanleitung (Original)' end, 'url', s.quelle)) end, '59840bbb-c123-4d85-9b75-0c171a35ec9f'
from werkzeug_spritzmittel s where s.id = 'b1542a7c-7aa4-42c2-9f00-3dfc40ee2c64';
update werkzeug_spritzmittel set wissen_eintrag_id = '43332cdb-7efc-4fcb-a90f-9a7ffc94141c' where id = 'b1542a7c-7aa4-42c2-9f00-3dfc40ee2c64';
insert into wissen_datei (id, eintrag_id, bereich, art, name, beschreibung, storage_pfad, groesse, erstellt_von)
select 'b3b861bc-d669-4828-aaf0-e5a5c6ac85d1', '43332cdb-7efc-4fcb-a90f-9a7ffc94141c', 'dokument', 'pdf', 'Gebrauchsanleitung ' || s.name || '.pdf', 'Gebrauchsanleitung', '43332cdb-7efc-4fcb-a90f-9a7ffc94141c/b3b861bc-d669-4828-aaf0-e5a5c6ac85d1.pdf', 46981, '59840bbb-c123-4d85-9b75-0c171a35ec9f' from werkzeug_spritzmittel s where s.id = 'b1542a7c-7aa4-42c2-9f00-3dfc40ee2c64';
