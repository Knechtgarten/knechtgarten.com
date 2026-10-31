-- Pendenzen: Zeitliste «Dieses Jahr» entfaellt (Zeit 1 Heute, 2 Diese Woche, 3 Dieser Monat, 0 Irgendwann).
-- Pendenzen mit Zeit 4 werden «Irgendwann», die Zeitliste 4 wird entfernt.
update pendenz set zeit = 0, zeit_sortierung = null where zeit = 4;
delete from pendenz_liste where zeit = 4;
alter table pendenz drop constraint if exists pendenz_zeit_check;
alter table pendenz add constraint pendenz_zeit_check check (zeit between 0 and 3);
alter table pendenz_liste drop constraint if exists pendenz_liste_zeit_check;
alter table pendenz_liste add constraint pendenz_liste_zeit_check check (zeit between 1 and 3);
