-- ============================================================================
-- Offertentool 2027 - Text pro Auswahloption + gesammelte Options-Textliste.
--
-- Jede Auswahloption (Tool B) kann jetzt einen Text hinterlegen. Wird eine
-- Option in einer Offerte (Formel oder Tagessatz) tatsaechlich gewaehlt, taucht
-- ihr Text am Schluss der Offerte in einer eigenen Liste auf ("- Optionsname:
-- Text", eine Zeile pro Option) - separat vom bestehenden, fortlaufenden
-- Beschreibungsblock. Gleiches Verhalten wie beim Beschreibungsblock: die
-- Liste wird automatisch neu zusammengestellt, ausser der Nutzer hat sie in
-- Tool A manuell angepasst - dann ueberschreibt die Automatik sie nicht mehr.
-- ============================================================================

alter table auswahloption add column if not exists beschreibung text null;

alter table offerte add column if not exists optionen_text_liste text null;
alter table offerte add column if not exists optionen_text_manuell boolean not null default false;
