-- Pendenzentool: Hintergrundfarbe pro Liste frei wählbar (Palette KG.palette).
-- null = automatisch: bei Palettenfarbe im Kopf Stufe 5 derselben Familie, bei alten Hex-Farben feine Tönung wie bisher.
alter table pendenz_liste add column if not exists farbe_hg text null;
