-- Pendenzen der Mitarbeitenden (Einsatzplaner): drei Spalten Heute / Diese Woche / Dieser Monat
-- statt «Heute / Morgen» + «Langfristig». Bisher langfristige Einträge kommen nach «Dieser Monat».
alter table planer_pendenz drop constraint if exists planer_pendenz_spalte_check;
update planer_pendenz set spalte = 'monat' where spalte = 'lang';
alter table planer_pendenz add constraint planer_pendenz_spalte_check check (spalte in ('tag', 'woche', 'monat'));
alter table planer_pendenz alter column spalte set default 'tag';
