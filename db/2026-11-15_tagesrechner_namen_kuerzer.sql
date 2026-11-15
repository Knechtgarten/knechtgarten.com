-- Tagesrechner: Teilschritt-Namen einzeilig (lange Erklärung bleibt in beschreibung = Mouse-over)
update public.teilschritt set name = v.neu from (values
 ('e64d4b2f-68e1-4573-8a90-5b9c378b3f77'::uuid,'Betonbeläge rückbauen'),
 ('b1803692-f8b2-45ba-ae75-ffe8ea3c2f4e','Grasnarbe abtragen'),
 ('ee99fcfe-6f6d-44d0-a03d-c7902b11da0b','Rodung Sträucher, Gehölze'),
 ('13e59735-6d0c-4f85-a04c-af13100dea4c','Bahnschwellen entfernen'),
 ('71ca85cd-d46a-4411-ac80-feccaf4aff2c','Rodung Wurzelstöcke'),
 ('cca4ee76-f842-48b1-a9e0-50abbc0ee0f2','Pflanzflächen auflockern'),
 ('0900f8d9-e487-400f-9755-3f457d786f9d','Handaushub mit Lieferwagen'),
 ('040aed5e-1f4e-4140-a5d7-91f7eef21b45','Maschinenaushub mit Lieferwagen'),
 ('c7c42e1a-a077-4ddd-93ee-d8d2a5a787d3','Humus mit Lieferwagen'),
 ('bb064836-d5be-448f-9ce9-184f473c056e','Maschinenaushub mit LKW'),
 ('45b00cc7-3a8e-442c-8435-14fe20b21c96','Material zwischendeponieren'),
 ('251b09bd-3dbf-42f0-9281-2dc917effc5e','Rasenfläche mit Ansaat'),
 ('4e9324bf-ed3a-488d-83b5-67ba131bf368','Humus mit LKW'),
 ('a6b870ee-d586-45cf-8061-7401f6078a46','Kies Fundation mit Lieferwagen')
) v(id, neu) where teilschritt.id = v.id;
-- (Beschreibung NICHT ergänzen: erscheint als Kundentext in «Hinweise» – wieder auf null gesetzt)
-- update public.teilschritt set beschreibung = ...
--  (entfernt)
-- Arbeitsschritt-Namen
update public.arbeitsschritt set name = 'Fundation, Hartflächen' where name = 'Fundation, Hartflächen,';
update public.arbeitsschritt set name = 'Eigene Arbeitsschritte' where name = 'Eigene Arbeitschritte';
