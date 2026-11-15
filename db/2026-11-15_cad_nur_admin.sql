-- CAD ist noch in Arbeit: nur Admin sieht Kachel und Tool-Menü (Admin sieht immer alles)
update public.modul_sichtbarkeit set fuer_buero_team = false, fuer_mitarbeitende = false, fuer_service_team = false where modul_key = 'cad';
select modul_key, fuer_buero_team, fuer_mitarbeitende, fuer_service_team from public.modul_sichtbarkeit where modul_key = 'cad';
