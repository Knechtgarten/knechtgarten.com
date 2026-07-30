-- ============================================================================
-- Offertentool 2027 - Notizen & Referenzen pro Artikel: freies Notizfeld
-- (Rich-Text wie bei den Offerten-Notizen), eine Liste mit Referenzpreisen
-- anderer Lieferanten/Quellen (rein informativ, keine Verknuepfung mit dem
-- Artikel-Datensatz) sowie ein einfaches 5-Spalten-Zusammenzaehl-Werkzeug.
-- ============================================================================

alter table artikel add column notiz text;
alter table artikel add column referenzpreise jsonb;
alter table artikel add column zusammenzaehl_tool jsonb;
