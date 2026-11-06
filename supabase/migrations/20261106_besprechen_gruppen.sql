-- «Besprechen»: Gruppen pro Büro-Person (ohne die eigene) in den bestehenden persönlichen Listen; Stefan bekommt die Liste neu
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y, farbe)
select b.id, 'besprechen', 'Besprechen', 'mitte', 460, 320, a.farbe
from pendenz_board b join benutzer u on u.id = b.besitzer_id, pendenz_art a
where b.typ = 'person' and u.email = 'mail@knechtgarten.ch' and a.id = 'besprechen'
  and not exists (select 1 from pendenz_liste l where l.board_id = b.id and l.art_id = 'besprechen');

insert into pendenz_gruppe (liste_id, titel, sortierung, zu)
select l.id, g.titel, g.nr, false
from pendenz_liste l join pendenz_board b on b.id = l.board_id and b.typ = 'person' join benutzer u on u.id = b.besitzer_id,
  (values ('mit Benu', 'benno', 1), ('mit Stefu', 'stefan', 2), ('mit Päscu', 'pascal', 3), ('mit Fäbu', 'fabian', 4), ('mit Marco', 'marco', 5)) g(titel, name, nr)
where l.art_id = 'besprechen' and lower(split_part(u.anzeigename, ' ', 1)) <> g.name
  and not exists (select 1 from pendenz_gruppe x where x.liste_id = l.id and x.titel = g.titel);
