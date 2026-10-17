-- Pflege & Service: eigene Kachel auf der Startseite (statt Eintrag unter Tools).
-- Sichtbar fuer Buero-Team (Admin sieht immer alles). Service-Team folgt mit
-- der Handy-Ansicht (Etappe 6) - umstellbar unter Verwaltung › Module.
insert into modul_sichtbarkeit (modul_key, name, kurzname, titel_mittel, text_gross, icon_key, hintergrund,
                                fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('pflegetool', 'Pflege & Service', 'Pflege', 'Pflege & Service',
        'Dauerpflege-Kunden, Jahresplan und Service-Einsätze.', 'pflege', 'gruen',
        true, false, false)
on conflict (modul_key) do nothing;
