-- Startseite: Kachel «Bewilligungen» (nur Büro; Admin sieht ohnehin alles)
insert into modul_sichtbarkeit (modul_key, name, kurzname, icon_key, hintergrund, fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('bewilligungen', 'Bewilligungen', 'Bewilligungen', 'bewilligung', 'gruen', true, false, false)
on conflict (modul_key) do nothing;
