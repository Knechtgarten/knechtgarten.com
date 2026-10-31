-- Pendenzen: Liste «Dauernde Notizen» im rechten Bereich (Allgemein) – Funktion wie die Team-box,
-- keine Pendenzenart für die Mitte. Icon Stecknadel (Pinnwand).
insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion)
values ('notizen', 'Dauernde Notizen', 'pin', '#5A7D9A', 120, true)
on conflict (id) do nothing;

-- in jedes eigene Board unter die Team-box
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y)
select b.id, 'notizen', 'Dauernde Notizen', 'team', 20, 160
from pendenz_board b
where b.typ = 'person'
  and not exists (select 1 from pendenz_liste l where l.board_id = b.id and l.art_id = 'notizen');
