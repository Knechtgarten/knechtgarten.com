-- Ferien: Betriebsferien Knecht (jedes Jahr gleiche KW) und Schulferien IDM Thun (Muster + genaue Daten 2025-2029 als Ausnahmen pro Jahr)
-- Schulferien Samstag-Sonntag laut IDM-Ferienplan 2025-2029 -> im Planer Montag bis Freitag
with neu as (
  insert into public.planer_ferien (name, art, von_kw, bis_kw, sortierung) values
    ('Sommerferien Knecht', 'betrieb', 30, 30, 10),
    ('Winterferien Knecht', 'betrieb', 52, 2, 20),
    ('Frühlingsferien Lernende (IDM)', 'lernende', 14, 16, 30),
    ('Sommerferien Lernende (IDM)', 'lernende', 27, 32, 40),
    ('Herbstferien Lernende (IDM)', 'lernende', 39, 41, 50),
    ('Winterferien Lernende (IDM)', 'lernende', 52, 1, 60)
  returning id, name)
insert into public.planer_ferien_ausnahme (ferien_id, jahr, von, bis)
select n.id, a.jahr, a.von::date, a.bis::date from neu n join (values
  ('Herbstferien Lernende (IDM)', 2025, '2025-09-22', '2025-10-10'),
  ('Herbstferien Lernende (IDM)', 2026, '2026-09-21', '2026-10-09'),
  ('Herbstferien Lernende (IDM)', 2027, '2027-09-27', '2027-10-15'),
  ('Herbstferien Lernende (IDM)', 2028, '2028-09-25', '2028-10-13'),
  ('Winterferien Lernende (IDM)', 2025, '2025-12-22', '2026-01-02'),
  ('Winterferien Lernende (IDM)', 2026, '2026-12-21', '2027-01-08'),
  ('Winterferien Lernende (IDM)', 2027, '2027-12-27', '2028-01-07'),
  ('Winterferien Lernende (IDM)', 2028, '2028-12-25', '2029-01-05'),
  ('Frühlingsferien Lernende (IDM)', 2026, '2026-03-30', '2026-04-17'),
  ('Frühlingsferien Lernende (IDM)', 2027, '2027-04-05', '2027-04-23'),
  ('Frühlingsferien Lernende (IDM)', 2028, '2028-04-03', '2028-04-21'),
  ('Frühlingsferien Lernende (IDM)', 2029, '2029-03-30', '2029-04-20'),
  ('Sommerferien Lernende (IDM)', 2026, '2026-06-29', '2026-08-07'),
  ('Sommerferien Lernende (IDM)', 2027, '2027-07-05', '2027-08-13'),
  ('Sommerferien Lernende (IDM)', 2028, '2028-07-03', '2028-08-11'),
  ('Sommerferien Lernende (IDM)', 2029, '2029-07-02', '2029-08-10')
) as a(name, jahr, von, bis) on a.name = n.name;
