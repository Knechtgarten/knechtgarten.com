-- Sonderzeilen (Termine, Kurse, Liefertermine) ohne Farbe: keine Maschinen-/Lieferwagen-Symbole
update planer_person set farbe = null where name in ('Termine', 'Kurse / Weiterbildung', 'Liefertermine');
