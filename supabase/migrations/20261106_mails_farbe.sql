-- Standardfarbe der Pendenzenart «Mails» (Beere Stufe 3), bestehende Listen mit der alten Standardfarbe angepasst
update pendenz_art set farbe = '#CC5E76' where id = 'mail';
update pendenz_liste set farbe = '#CC5E76' where art_id = 'mail' and farbe = '#6E4C35';
