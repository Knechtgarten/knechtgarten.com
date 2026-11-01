-- ============================================================================
-- Einsatzplaner: Personenfarben auf die neue Palette (Gesamt-Tool, Variante C).
-- Vorher alle bisherigen Farben in planer_person_farbe_alt sichern (zurückholen:
--   update planer_person p set farbe = a.farbe from planer_person_farbe_alt a where a.person_id = p.id;)
-- Projektleiter Grün 2–5 · Gartenbau Violett/Petrol/Blau · Gartenpflege Gold/Orange · Pool hellblau.
-- Lehrlinge / Hilfsarbeitende haben keine eigene Farbe (ihre Tage zeigen die Farbe des Vorarbeiters).
-- ============================================================================
create table if not exists planer_person_farbe_alt (
  person_id uuid primary key references planer_person(id) on delete cascade,
  farbe text,
  gesichert_am timestamptz not null default now()
);
alter table planer_person_farbe_alt enable row level security;
drop policy if exists planer_person_farbe_alt_admin on planer_person_farbe_alt;
create policy planer_person_farbe_alt_admin on planer_person_farbe_alt for all using (ist_admin()) with check (ist_admin());

insert into planer_person_farbe_alt (person_id, farbe)
select id, farbe from planer_person
on conflict (person_id) do nothing;

with neu(name, farbe) as (values
  ('Benu', '#3F7D3F'), ('Stefan', '#62A055'), ('Fabian Oberholzer', '#9CC98A'), ('Pascal Wüthrich', '#D3EBC7'),
  ('Dominic Glur', '#5C3F94'), ('Remo Reusser', '#3F9890'), ('Timo Jost', '#2F5C9A'),
  ('Stefanie Röthlisberger', '#AD95DD'), ('Kai Abgottspon', '#4F80C2'), ('Fabian Reusser', '#8063BD'),
  ('Cornelia Hirschi', '#E0AE24'), ('Selina Durrer', '#E57E34'), ('Samir Akhdar', '#F2CF5E'), ('Andrea Hadorn', '#F2A66B'),
  ('Marco Gfeller', '#CCDDF2'),
  ('Sandra Rufener', null), ('Dian Baumann', null))
update planer_person p set farbe = n.farbe
from neu n where p.name = n.name and p.aktiv and p.archiviert_am is null;
