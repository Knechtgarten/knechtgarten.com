-- Promanal Neu: nur noch Hersteller-Dosierung 2 % (Schrank-Etikett 150 ml / 50 L entfernt, Entscheid Nutzer 2026-11-02)
update werkzeug_spritzmittel
set dosierungen = '[{"n":"Bäume, Sträucher 2 %","menge":200,"pro_l":10}]'::jsonb, geaendert_am = now()
where name = 'Promanal Neu';
