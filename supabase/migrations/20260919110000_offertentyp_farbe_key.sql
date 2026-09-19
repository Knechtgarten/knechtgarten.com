-- Individuelle Hintergrundfarbe pro Offertentyp fuer die Buttons im "Neue
-- Offerte"-Fenster (Tool A/Start) - feste Auswahl aus den bestehenden
-- Tool-Farben (siehe OFFERTENTYP_FARBEN in tool-b-live-v1.html), analog zu
-- icon_key. null = bisherige Standardfarbe (modellabhaengig).
alter table offertentyp add column farbe_key text null;
