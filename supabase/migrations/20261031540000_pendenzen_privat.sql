-- Pendenzen: Liste «Privat» (Schloss) – nur im eigenen Board, nicht versendbar, nie in gemeinsamen Boards
insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion)
values ('privat', 'Privat', 'schloss', '#556B5A', 105, false)
on conflict (id) do nothing;

-- in jedes eigene Board unten an die Pendenzen-Listen anhängen
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y)
select b.id, 'privat', 'Privat', 'mitte', 20,
  coalesce((select max(l.y) from pendenz_liste l where l.board_id = b.id and l.bereich = 'mitte'), 0) + 200
from pendenz_board b
where b.typ = 'person'
  and not exists (select 1 from pendenz_liste l where l.board_id = b.id and l.art_id = 'privat');
