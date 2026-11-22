-- Sicherheitsdatenblatt (bereich 'sdb', genau eines pro Produkt, druckbar als Kanister-Kleber) getrennt von
-- Merkblättern (bereich 'sicherheit', beliebig viele). Bestehende Dateien «Sicherheitsdatenblatt …» werden 'sdb'.
alter table public.wissen_datei drop constraint if exists wissen_datei_bereich_check;
alter table public.wissen_datei add constraint wissen_datei_bereich_check check (bereich in ('anwendung', 'notiz', 'dokument', 'sicherheit', 'sdb'));
update public.wissen_datei set bereich = 'sdb' where bereich = 'sicherheit' and exemplar_id is null and name ilike 'sicherheitsdatenblatt%';
select bereich, count(*) as anzahl from public.wissen_datei where bereich in ('sdb', 'sicherheit') group by bereich order by 1;
