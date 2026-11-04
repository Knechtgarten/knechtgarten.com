-- Pflege-Tool: Arbeiten dürfen länger als 24 Std. dauern (mehrtägiger Winterschnitt, z. B. 27 Std. = 3 Tage)
alter table pflege_kunde_arbeit drop constraint if exists pflege_kunde_arbeit_dauer_min_check;
alter table pflege_kunde_arbeit add constraint pflege_kunde_arbeit_dauer_min_check check (dauer_min >= 5 and dauer_min <= 6000);
