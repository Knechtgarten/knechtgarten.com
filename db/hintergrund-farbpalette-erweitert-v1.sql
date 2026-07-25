-- ============================================================================
-- Offertentool 2027 - Erweiterte Farbpalette fuer Kachel-Hintergruende (nur
-- fuer die Hintergrundfarbe von Kacheln relevant, sonst nirgends in der App).
-- Navy faellt weg (Mitarbeitende-Standard fuer eigene Links ist ohnehin
-- schon Grau, siehe app/index.html), dafuer kommen vier neue Toene dazu.
-- Bestehende 'navy'-Werte werden vor der Umstellung best effort auf 'grau'
-- zurueckgesetzt.
-- ============================================================================

update modul_sichtbarkeit set hintergrund = 'grau' where hintergrund = 'navy';
alter table modul_sichtbarkeit drop constraint modul_sichtbarkeit_hintergrund_check;
alter table modul_sichtbarkeit add constraint modul_sichtbarkeit_hintergrund_check
  check (hintergrund in ('blau', 'gruen', 'grau', 'grau_dunkel', 'sandbeige', 'fliedergrau', 'puderrosa'));

update benutzer_eigener_link set hintergrund = 'grau' where hintergrund = 'navy';
alter table benutzer_eigener_link drop constraint benutzer_eigener_link_hintergrund_check;
alter table benutzer_eigener_link add constraint benutzer_eigener_link_hintergrund_check
  check (hintergrund in ('blau', 'gruen', 'grau', 'grau_dunkel', 'sandbeige', 'fliedergrau', 'puderrosa'));
