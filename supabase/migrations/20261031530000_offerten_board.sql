-- ============================================================================
-- Pendenzen: Offerten-Board (ein gemeinsames Board, Ansicht «meine» = gefiltert nach offerte_von)
--
-- Listen = feste Funktions-Arten: Zugestellt → Nachgefasst → Meldet sich wieder / Aufgeschoben /
-- Keine Rückmeldung → Abgesagt (nach 30 Tagen automatisch archiviert). Zugesagt = Ablagefeld in der
-- Leiste → Büro-Board, Liste «Planung» (pendenz_liste.rolle = 'planung').
-- pendenz.liste_seit: seit wann in der aktuellen Liste (Trigger) → Erinnerung nach 14 Tagen in «Heute».
-- ============================================================================

alter table pendenz_board drop constraint if exists pendenz_board_typ_check;
alter table pendenz_board add constraint pendenz_board_typ_check check (typ in ('person', 'gemeinsam', 'firma', 'offerten'));

alter table pendenz_liste add column if not exists rolle text null;
update pendenz_liste l set rolle = 'planung'
from pendenz_board b
where b.id = l.board_id and b.mail_kuerzel = 'buero' and l.titel = 'Planung';

alter table pendenz add column if not exists chance smallint null check (chance between 1 and 3);
alter table pendenz add column if not exists wieder_am date null;
alter table pendenz add column if not exists offerte_von uuid null references benutzer(id) on delete set null on update cascade;
alter table pendenz add column if not exists offerte_status text null check (offerte_status in ('zugesagt', 'abgesagt', 'archiviert'));
alter table pendenz add column if not exists liste_seit timestamptz not null default now();

create or replace function pendenz_liste_seit() returns trigger language plpgsql as $$
begin
  if new.liste_id is distinct from old.liste_id then new.liste_seit := now(); end if;
  return new;
end $$;
drop trigger if exists pendenz_liste_seit_trg on pendenz;
create trigger pendenz_liste_seit_trg before update on pendenz for each row execute function pendenz_liste_seit();

insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion) values
  ('of_zugestellt',   'Zugestellt',         'senden',     '#3F6E8C', 200, true),
  ('of_nachgefasst',  'Nachgefasst',        'telefon',    '#4F7C8A', 210, true),
  ('of_meldet',       'Meldet sich wieder', 'zurueck',    '#5F8A6B', 220, true),
  ('of_aufgeschoben', 'Aufgeschoben',       'jahr',       '#8C7A5B', 230, true),
  ('of_keine',        'Keine Rückmeldung',  'stumm',      '#46505E', 240, true),
  ('of_abgesagt',     'Abgesagt',           'absage',     '#8E5B4A', 250, true)
on conflict (id) do nothing;

-- ein Offerten-Board für das Büro-Team (gleiche Mitglieder wie das Büro-Board)
with b as (
  insert into pendenz_board (name, typ, mail_kuerzel) values ('Offerten', 'offerten', 'offerten') returning id
), m as (
  insert into pendenz_board_mitglied (board_id, benutzer_id)
  select b.id, bm.benutzer_id from b, pendenz_board_mitglied bm
  join pendenz_board bb on bb.id = bm.board_id and bb.mail_kuerzel = 'buero'
  returning 1
)
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y, breite)
select b.id, v.art_id, v.titel, 'mitte', v.x, 20, 240 from b, (values
  ('of_zugestellt',   'Zugestellt',         20),
  ('of_nachgefasst',  'Nachgefasst',        280),
  ('of_meldet',       'Meldet sich wieder', 540),
  ('of_aufgeschoben', 'Aufgeschoben',       800),
  ('of_keine',        'Keine Rückmeldung',  1060),
  ('of_abgesagt',     'Abgesagt',           1320)
) as v(art_id, titel, x);
