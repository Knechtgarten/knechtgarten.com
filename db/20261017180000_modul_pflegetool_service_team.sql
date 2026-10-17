-- Etappe 6 (Handy-Ansicht): Kachel «Pflege & Service» auch fuer das Service-Team.
-- Techniker landen beim Oeffnen automatisch in pflege-handy-live-v1.html.
update modul_sichtbarkeit set fuer_service_team = true where modul_key = 'pflegetool';
