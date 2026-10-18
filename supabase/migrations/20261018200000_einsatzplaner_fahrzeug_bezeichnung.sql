-- Lieferwagen: Kontrollschild ins Feld «nummer», Bezeichnung ins Feld «name»
-- (Vorname des Stamm-Fahrers, ohne Stamm-Fahrer «Lieferwagen 1/2/3»)
update planer_ressource r set nummer = r.name, name = split_part(p.name, ' ', 1)
from planer_person p
where r.typ = 'fahrzeug' and r.nummer is null and p.id = r.stamm_person_id;
update planer_ressource r set nummer = r.name, name = v.bez
from (values ('BE-896782', 'Lieferwagen 1'), ('BE-814529', 'Lieferwagen 2'), ('BE-668658', 'Lieferwagen 3')) v(schild, bez)
where r.typ = 'fahrzeug' and r.nummer is null and r.name = v.schild;
