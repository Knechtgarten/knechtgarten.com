-- ============================================================================
-- Offertentool 2027 - Eigenes Icon fuer die eigenen Links auf der Startseite.
-- Standardmaessig wird kein eigenes Icon benoetigt: index.html versucht
-- automatisch das Favicon der hinterlegten URL zu laden (per Google-
-- Favicon-Dienst, kein eigener Upload/Speicher noetig), mit Platzhalter-Icon
-- als Rueckfall falls das fehlschlaegt. icon_url ist nur die manuelle
-- Ueberschreibung, falls der Benutzer lieber ein anderes Bild verlinken will.
-- ============================================================================

alter table benutzer_eigener_link add column icon_url text;
