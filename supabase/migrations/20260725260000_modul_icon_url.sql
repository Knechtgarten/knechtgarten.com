-- ============================================================================
-- Offertentool 2027 - Eigenes Icon fuer externe Tools: bei ist_extern=true
-- legt der Admin das Icon komplett selbst fest (Bild-URL, keine Auswahl aus
-- unserer Icon-Bibliothek). Ohne eigenes icon_url wird wie bei den
-- persoenlichen Links automatisch das Favicon der hinterlegten URL
-- verwendet. Bei den Tools, die wir gemeinsam bauen (ist_extern=false),
-- bleibt es bei icon_key aus unserer eigenen Icon-Bibliothek.
-- ============================================================================

alter table modul_sichtbarkeit add column icon_url text;
