-- Neue Pendenzenarten: Allgemein (Ebenen, grau) und Bestellungen (Einkaufswagen, orange)
insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion, aktiv) values
  ('allgemein', 'Allgemein', 'ebenen', '#6E7F93', 55, false, true),
  ('bestellungen', 'Bestellungen', 'wagen', '#C05A1C', 58, false, true)
on conflict (id) do nothing;
