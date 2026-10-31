-- Offerten-Board: «Keine Rückmeldung» heisst neu «Funkstille» (nach 120 Tagen automatisch archiviert),
-- neue Liste «Zugesagt» ganz rechts (hellblau) = zeigt die zugesagten Offerten aus Büro-Board «Planung».
-- Sieben Listen à 210 px nebeneinander.
alter table pendenz drop constraint if exists pendenz_offerte_status_check;
alter table pendenz add constraint pendenz_offerte_status_check check (offerte_status in ('zugesagt', 'abgesagt', 'funkstille', 'archiviert'));

update pendenz_art set titel = 'Funkstille' where id = 'of_keine';
update pendenz_liste set titel = 'Funkstille' where art_id = 'of_keine';

insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion)
values ('of_zugesagt', 'Zugesagt', 'haken', '#D6E7F4', 260, true)
on conflict (id) do nothing;

insert into pendenz_liste (board_id, art_id, titel, bereich, x, y, breite)
select b.id, 'of_zugesagt', 'Zugesagt', 'mitte', 1400, 20, 210
from pendenz_board b
where b.typ = 'offerten'
  and not exists (select 1 from pendenz_liste l where l.board_id = b.id and l.art_id = 'of_zugesagt');

update pendenz_liste l set breite = 210, y = 20, x = v.x
from (values ('of_zugestellt', 20), ('of_nachgefasst', 250), ('of_meldet', 480), ('of_aufgeschoben', 710),
             ('of_keine', 940), ('of_abgesagt', 1170), ('of_zugesagt', 1400)) as v(art_id, x)
where l.art_id = v.art_id;
