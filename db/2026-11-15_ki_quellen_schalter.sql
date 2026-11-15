-- KI-Offerte: Zusatzquellen (internet, drive, peax, mails) pro Offerte eingeschaltet
alter table public.offerte add column if not exists ki_quellen text[] not null default '{}';
select count(*) from public.offerte where ki_quellen <> '{}';
