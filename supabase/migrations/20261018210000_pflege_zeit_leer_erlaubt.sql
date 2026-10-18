-- Standardzeit einer Pflege-Arbeit darf leer sein (Zeit haengt dann immer vom Kunden ab).
-- Die bisherigen 60 Minuten waren nur der automatische Startwert, noch nie erfasst: leeren.
alter table pflege_arbeit alter column dauer_min drop not null;
alter table pflege_arbeit alter column dauer_min drop default;
update pflege_arbeit set dauer_min = null where dauer_min = 60;
