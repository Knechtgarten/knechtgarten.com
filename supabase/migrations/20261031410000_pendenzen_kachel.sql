-- Startseite: Kachel «Pendenzen» (vorerst Büro-Team + Admin)
insert into modul_sichtbarkeit (modul_key, name, kurzname, titel_mittel, text_gross, hintergrund, ist_extern, fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('pendenzen', 'Pendenzen', 'Pendenzen', 'Pendenzen', 'Dein Board: Pendenzen nach Art, Zeit und Team.', 'blau', false, true, false, false)
on conflict (modul_key) do nothing;
