-- Ferien auch nach Datum (MM-TT, jedes Jahr gleich; auch einzelne Tage), KW optional
alter table public.planer_ferien add column if not exists von_md text check (von_md ~ '^\d{2}-\d{2}$');
alter table public.planer_ferien add column if not exists bis_md text check (bis_md ~ '^\d{2}-\d{2}$');
alter table public.planer_ferien alter column von_kw drop not null;
alter table public.planer_ferien alter column bis_kw drop not null;
-- Winter: Betrieb 3 Wochen geschlossen = «Winterferien Knecht» (KW 52 bis KW 2); der Arbeitszeit-Eintrag «Betriebsschluss» entfällt
delete from public.planer_arbeitszeit where start is null and ab_kw = 52;
