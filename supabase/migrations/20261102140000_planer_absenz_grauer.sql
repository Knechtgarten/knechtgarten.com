-- ============================================================================
-- Einsatzplaner: Absenzen etwas dunkler grau (alle Absenzen nehmen den Grauton von «Frei»),
-- passend zu den voll eingefärbten Aufträgen. Stufe 0 (#E3E6E9) -> 2 (#BCC2C8).
-- ============================================================================
update planer_absenz_typ set grauton = 2 where name = 'Frei';
