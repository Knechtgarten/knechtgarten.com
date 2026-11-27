-- Felder der aufgelösten Kategorien (Winterschnitt, Biopool …), 2026-11-27 mitverschoben (reihenfolge >= 100), alle ohne Werte: entfernen
delete from pflege_feld f
 where f.reihenfolge >= 100
   and not exists (select 1 from pflege_kunde_kategorie kk where kk.werte ? f.id::text);
