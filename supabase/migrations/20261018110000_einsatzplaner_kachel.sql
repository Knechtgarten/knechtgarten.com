-- Einsatzplaner: Kachel auf der Startseite. Vorerst nur Admin + Buero-Team,
-- Mitarbeitende / Service-Team schaltet Stefan in der Verwaltung frei,
-- sobald die Personen erfasst und mit ihrem Login verknuepft sind.
insert into modul_sichtbarkeit (modul_key, name, kurzname, titel_mittel, text_gross, icon_key, hintergrund, fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values ('einsatzplaner', 'Einsatzplaner', 'Planer', 'Einsatzplaner', 'Wer arbeitet wann wo: Baustellen, Termine, Absenzen.', 'planer', 'blau', true, false, false)
on conflict (modul_key) do nothing;
