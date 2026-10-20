-- ============================================================================
-- Bewaesserungsplan: neben Rohnertec (Spalte bewaesserung) einfache Steuergeraete
-- pflege_kunde_kategorie.bewaesserung_geraete = {
--   "rainbird": [{ name, von, bis, tage:[0..6] }],          -- Zone, ein Zeitfenster
--   "claber":   [{ name, start, freq, dauer }],             -- Frequenz + Bewaesserungszeit
--   "geka":     [{ name, start, freq, dauer }]              -- Intervall + Laufzeit
-- }  (start = ungefaehre Startzeit, freq/dauer = Werte wie am Geraet angeschrieben)
-- ============================================================================
alter table pflege_kunde_kategorie add column bewaesserung_geraete jsonb not null default '{}'::jsonb;
