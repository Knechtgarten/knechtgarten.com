-- Planer: Zeile bestimmt offen/fix (2026-11-27). Offene Aufträge mit «fixer Woche» in der Hauptzeile gibt es nicht mehr:
-- sie wandern in die Zeile «offen» derselben Person (abgemacht bleibt false, fixe_woche aus).
update public.planer_einsatz set fixe_woche = false where fixe_woche and not abgemacht;
select (select count(*) from public.planer_einsatz where fixe_woche) rest_fixe_woche;
