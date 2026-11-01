-- ============================================================================
-- Einsatzplaner: Projektleiter-Farben deutlich unterschiedlicher (Grün dunkel, Oliv, Grün hell, Limette).
-- «Selber abgemacht» (ohne Projektleiter) bekommt im Code die Farbe des Planer-Icons (Petrol).
-- planer_person_farbe_alt enthält schon die Farben vor Variante C und bleibt unverändert.
-- Vorher (zum Zurücksetzen): Stefan #62A055, Fabian Oberholzer #9CC98A, Pascal Wüthrich #D3EBC7, Benu #3F7D3F
-- ============================================================================

with neu(name, farbe) as (values
  ('Stefan', '#2E5A2F'),            -- Grün Stufe 1
  ('Fabian Oberholzer', '#7C8726'), -- Oliv Stufe 2
  ('Pascal Wüthrich', '#9CC98A'),   -- Grün Stufe 4
  ('Benu', '#C9D35E'))              -- Oliv Stufe 4
update planer_person p set farbe = n.farbe from neu n where p.name = n.name and p.aktiv and p.ist_projektleiter;
