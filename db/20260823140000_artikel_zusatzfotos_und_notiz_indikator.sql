-- ============================================================================
-- Bis zu 3 Zusatzfotos pro Artikel (Artikelstamm-Pflege): das erste Foto
-- (bestehende Spalte foto_url) bleibt das Hauptfoto fuer die Artikeluebersicht,
-- die drei Zusatzfotos sind nur in der Detailansicht (Artikel bearbeiten)
-- sichtbar.
-- ============================================================================

alter table artikel add column zusatzfoto1_url text;
alter table artikel add column zusatzfoto2_url text;
alter table artikel add column zusatzfoto3_url text;
