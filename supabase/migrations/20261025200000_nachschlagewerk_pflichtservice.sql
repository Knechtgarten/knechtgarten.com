-- Nachschlagewerk: neue Art «Pflichtservice». Im Serviceplan setzt sie den Planer automatisch auf Pflicht (wichtig).
alter table public.wissen_service_erledigt drop constraint if exists wissen_service_erledigt_art_check;
alter table public.wissen_service_erledigt add constraint wissen_service_erledigt_art_check
  check (art in ('Service', 'Pflichtservice', 'Reparatur', 'Prüfung', 'Kontrolle'));
alter table public.wissen_service drop constraint if exists wissen_service_art_check;
alter table public.wissen_service add constraint wissen_service_art_check
  check (art in ('Service', 'Pflichtservice', 'Reparatur', 'Prüfung', 'Kontrolle'));

-- bisherige Pflicht-Arbeiten (im Planer, wichtig) werden Pflichtservice, ebenso ihre erledigten Einträge
update public.wissen_service set art = 'Pflichtservice' where im_planer and wichtig and art = 'Service';
update public.wissen_service_erledigt r set art = 'Pflichtservice'
  from public.wissen_service s where s.id = r.service_id and s.art = 'Pflichtservice' and r.art = 'Service';
