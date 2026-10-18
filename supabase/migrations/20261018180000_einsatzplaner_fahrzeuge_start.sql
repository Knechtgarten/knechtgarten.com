-- Einsatzplaner: Lieferwagen aus der Fahrzeugliste (Stand 2026-10-18)
-- Name = Kontrollschild, Stamm-Fahrer wie in der Liste. «NEU» = noch kein Stamm-Fahrer.
-- Patrick (VW Caddy) ist noch keine Zeile im Planer: Stamm-Fahrer bleibt leer.
insert into planer_ressource (typ, name, stamm_person_id, sortierung)
select 'fahrzeug', v.schild, (select id from planer_person p where p.name = v.fahrer), v.sort
from (values
  ('BE-846047', 'Andrea Hadorn', 10), ('BE-424586', 'Cornelia Hirschi', 20), ('BE-555732', 'Selina Durrer', 30),
  ('BE-848254', 'Samir Akhdar', 40), ('BE-464602', 'Dominic Glur', 50), ('BE-518853', 'Stefanie Röthlisberger', 60),
  ('BE-545313', 'Timo Jost', 70), ('BE-533628', 'Kai Abgottspon', 80), ('BE-881138', 'Remo Reusser', 90),
  ('BE-896782', null, 100), ('BE-814529', null, 110),
  ('BE-759185', 'Marco Gfeller', 120), ('BE-668658', null, 130)
) v(schild, fahrer, sort)
where not exists (select 1 from planer_ressource r where r.typ = 'fahrzeug' and r.name = v.schild);
