-- Arbeitszeit ab Kalenderwoche (jedes Jahr ab Montag dieser KW) statt ab Datum
alter table public.planer_arbeitszeit add column if not exists ab_kw int check (ab_kw between 1 and 53);
update public.planer_arbeitszeit set ab_kw = case
  when ab_monat = 1 and ab_tag = 1 then 1
  when ab_monat = 2 and ab_tag = 9 then 7
  when ab_monat = 3 and ab_tag = 2 then 10
  when ab_monat = 11 and ab_tag = 16 then 47
  when ab_monat = 12 and ab_tag = 20 then 52
  else extract(week from make_date(2026, ab_monat, ab_tag))::int end
where ab_kw is null;
alter table public.planer_arbeitszeit alter column ab_kw set not null;
alter table public.planer_arbeitszeit alter column ab_monat drop not null;
alter table public.planer_arbeitszeit alter column ab_tag drop not null;
alter table public.planer_arbeitszeit drop constraint if exists planer_arbeitszeit_ab_monat_ab_tag_key;
create unique index if not exists planer_arbeitszeit_ab_kw on public.planer_arbeitszeit (ab_kw);
-- Vorrat «Lehrlinge» entfällt (Schulferien kommen in Arbeitszeit & Ferien, Prüfungen als Balken in Termine & Infos); Einträge vorher sichern
create table if not exists backup.planer_vorrat_lehrling_20261105 as select * from public.planer_vorrat where bereich = 'lehrling';
delete from public.planer_vorrat where bereich = 'lehrling';
