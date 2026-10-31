-- Pendenzen: «Sammelbox» – eigener Eingang (vom Handy über die Web-App «Pendenzen», später auch Mails an sich selbst).
-- Fest in jedem eigenen Board rechts (Allgemein) unter der Team-box. herkunft 'handy' = über die Web-App erfasst.
insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion)
values ('sammel', 'Sammelbox', 'sammel', '#3F6E8C', 115, true)
on conflict (id) do nothing;

alter table pendenz drop constraint if exists pendenz_herkunft_check;
alter table pendenz add constraint pendenz_herkunft_check check (herkunft in ('board', 'mail', 'handy'));

insert into pendenz_liste (board_id, art_id, titel, bereich, x, y)
select b.id, 'sammel', 'Sammelbox', 'team', 20, 150
from pendenz_board b
where b.typ = 'person'
  and not exists (select 1 from pendenz_liste l where l.board_id = b.id and l.art_id = 'sammel');
