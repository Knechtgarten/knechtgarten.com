-- Verblendmauer: Abdeckung, Ecken, Stirnseiten nicht mehr als Tabellenspalten, sondern als Mengenfeld an den Knöpfen
-- (Teilschritt «Zusatzarbeiten Verblendmauer»). Keine bestehende Offerte nutzt diese Knöpfe (geprüft 2026-11-14).
begin;
-- 1) Mengenfelder an den Knöpfen
update public.auswahloption set mengenoption = true, mengenoption_einheit = 'm'
 where id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f',   -- Ecken Toce / Cascata
              '488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b');  -- Abdeckplatte Piasentina / Geopietra Abdeckung
update public.auswahloption set mengenoption = true, mengenoption_einheit = 'Stk.'
 where id in ('ff34bf33-ffb9-4da1-a0b0-3d2c1c2d6ae9','fd7c5bf0-4852-4706-8bde-df64a25ec629');  -- Stirnseite Cortenblech / Blech Anthrazit
-- 2) Formeln: statt Spaltensumme jetzt «je Meter» (Menge aus dem Knopf multipliziert das Tool)
update public.ressourcenzeile set menge_ausdruck = replace(replace(menge_ausdruck::text,
    '{"id": "7458a687-278c-4492-ae65-5e30d0f4a494", "ref": "term"}', '{"lit": 1}'),
    '{"id": "219085c9-2abd-45de-b15e-f527f67e4b39", "ref": "term"}', '{"lit": 1}')::jsonb
 where option_id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f','488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b');
-- Fugenmaterial Adheaseal: Aufrunden geht pro Meter nicht mehr sinnvoll -> 0.1356 Kartuschen je Meter
update public.ressourcenzeile set menge_ausdruck = '{"op": "*", "args": [{"lit": 1}, {"lit": 0.1356}]}'::jsonb where id = '43d3c94c-c860-47c9-a14b-82d64b5bdf3a';
-- Stirnseite je Stück: mittlere Mauerhöhe (Fläche / Länge) x 1.1, Menge = Anzahl Stirnseiten im Knopf
update public.term set name = 'Stirnhöhe je Stirnseite Verblendmauer',
  ausdruck = '{"op": "*", "args": [{"op": "/", "args": [{"id": "79d12cd1-fbee-4eb6-a000-8868c6bc490b", "ref": "spalte"}, {"op": "+", "args": [{"id": "521d1b57-9a36-47b8-baac-3fab8e6a8281", "ref": "spalte"}, {"lit": 0.000001}]}]}, {"lit": 1.1}]}'::jsonb,
  formel_modus = 'baukasten', formel_text = null, formel_baukasten_ausdruck = null
 where id = 'da85244e-1972-4861-8a8e-1d2afdb0e1ad';
-- 3) Spalten Abdeckung, Ecken, Stirnen in der Tabelle ausblenden (nicht löschen)
update public.eingabefeld_tabelle_spalte set ausgeblendet = true
 where id in ('83cd04d0-587f-4354-88de-abbdb7884e44','9ffaff92-2c67-4bed-a820-e88cc26e80ca','ce50631a-3ccd-4320-912b-5406426e9c10');
commit;
select o.name, o.mengenoption, o.mengenoption_einheit from public.auswahloption o where o.id in ('4f08273e-efb8-4d0a-8816-467e9fdf7a4a','f3efda6f-555b-484c-a755-2b96ba15922f','488338df-92f5-4c47-947e-7c938765833c','758c3902-4d67-4215-9f71-5024a241585b','ff34bf33-ffb9-4da1-a0b0-3d2c1c2d6ae9','fd7c5bf0-4852-4706-8bde-df64a25ec629');
