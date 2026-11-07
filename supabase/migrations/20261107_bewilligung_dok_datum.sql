-- Ein Datum für alle Dokumente eines Gesuchs (Näherbaurecht, Zustimmung, Lärmschutznachweis); leer = heute
alter table public.bewilligung add column if not exists dok_datum date;
