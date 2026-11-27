-- Projektleiter für Pflege (Farbe im Planer): Vorgabe pro Pflegekategorie, beim Kunden pro Kategorie überschreibbar.
-- Wert: planer_person.id als Text, 'selbst' (Zuständiger macht selbst ab → schwarz), 'keine' (grau).
-- pflege_kunde_kategorie.projektleiter = null heisst: Vorgabe der Kategorie gilt.
alter table public.pflege_kategorie add column if not exists projektleiter text;
alter table public.pflege_kunde_kategorie add column if not exists projektleiter text;
select (select count(*) from public.pflege_kategorie) kategorien;
