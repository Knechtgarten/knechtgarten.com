-- Einsatzplaner: erste Maschinen aus Tom's Planner (Stand 2026-10-18)
insert into planer_ressource (typ, name, sortierung)
select 'maschine', v.name, v.sort
from (values ('Bagger 2.1', 10), ('Bagger 2.2', 20), ('Bagger 2.3', 30), ('Bagger 3.2', 40), ('Bagger 3.1', 50),
             ('Bagger 9.1', 60), ('Bagger 9.2', 70), ('Radtumper gross', 80)) v(name, sort)
where not exists (select 1 from planer_ressource r where r.typ = 'maschine' and r.name = v.name);
