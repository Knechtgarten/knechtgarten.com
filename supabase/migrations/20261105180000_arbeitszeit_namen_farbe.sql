-- Arbeitszeit & Ferien: Name pro Arbeitszeit-Zeitraum, Farbe pro Ferien (leer = grau)
alter table public.planer_arbeitszeit add column if not exists name text;
alter table public.planer_ferien add column if not exists farbe text;
update public.planer_arbeitszeit set name = case ab_kw when 1 then 'Arbeitsstart Winter' when 7 then 'Arbeitsstart Februar' when 10 then 'Arbeitsstart Frühling' when 47 then 'Arbeitszeit Herbst' when 52 then 'Betriebsschluss Weihnachten' end where name is null;
