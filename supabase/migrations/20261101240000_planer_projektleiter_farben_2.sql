-- ============================================================================
-- Einsatzplaner: Projektleiter-Farben neu zugeteilt (Wunsch Stefan, 2026-11-01)
-- Grün dunkel = Stefan, Oliv = Benu, Grün hell = Fabian Oberholzer, Limette = selber abgemacht (im Code), Petrol = Pascal
-- Vorher (20261101230000): Stefan #2E5A2F, Fabian #7C8726, Pascal #9CC98A, Benu #C9D35E
-- ============================================================================
with neu(name, farbe) as (values
  ('Stefan', '#2E5A2F'),            -- Grün Stufe 1
  ('Benu', '#7C8726'),              -- Oliv Stufe 2
  ('Fabian Oberholzer', '#9CC98A'), -- Grün Stufe 4
  ('Pascal Wüthrich', '#2A7570'))   -- Petrol Stufe 2
update planer_person p set farbe = n.farbe from neu n where p.name = n.name and p.aktiv and p.ist_projektleiter;
