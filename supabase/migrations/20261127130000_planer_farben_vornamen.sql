-- Zuständigkeits-Farben neu (2026-11-27): Fabian Grün mittel, selber abgemacht Grün hell, System (Pflege) Limette.
-- Büro-Zeilen im Planer nur mit Vornamen. Projektleiter pro Pflegekategorie entfällt (Spalten bleiben, werden nicht mehr gelesen).
update public.planer_person set farbe = '#62A055', name = 'Fabian' where name = 'Fabian Oberholzer';
update public.planer_person set name = 'Pascal' where name = 'Pascal Wüthrich';
update public.pflege_kategorie set projektleiter = null where projektleiter is not null;
update public.pflege_kunde_kategorie set projektleiter = null where projektleiter is not null;
select name, farbe from public.planer_person where name in ('Benu','Stefan','Fabian','Pascal');
