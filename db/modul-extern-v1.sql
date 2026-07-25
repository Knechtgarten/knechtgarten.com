-- ============================================================================
-- Offertentool 2027 - Externe Tools als eigene Kacheln: Admin kann jetzt in
-- der Verwaltung neue Kacheln fuer externe Tools (Gmail, Easybill, Kalender
-- usw.) anlegen, mit eigenem Titel/Icon/Hintergrund/URL und Rollen-Freigabe -
-- genau wie die fest im Code hinterlegten Tools (Offertentool + Platzhalter),
-- nur eben dynamisch statt per Code hinzugefuegt.
--
-- ist_extern unterscheidet die beiden Arten von Zeilen: false (Standard) =
-- fest im HTML von index.html verankerte Kachel, wird nur von uns per Code
-- ergaenzt. true = vom Admin selbst angelegt, wird von index.html dynamisch
-- als zusaetzliche Kachel erzeugt (aehnlich wie eigene Links, aber rollen-
-- basiert statt pro Benutzer) und kann vom Admin auch wieder geloescht
-- werden.
-- ============================================================================

alter table modul_sichtbarkeit add column ist_extern boolean not null default false;
