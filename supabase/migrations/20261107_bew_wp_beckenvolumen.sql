-- Beckenvolumen laut Hersteller (mit Poolabdeckung), für den Vorschlag der Wärmepumpe aus dem Poolvolumen.
-- Vorschlag nimmt immer den unteren Wert (vol_min) als Grenze: kleinste Wärmepumpe mit vol_min >= Poolvolumen.
alter table public.bew_waermepumpe add column if not exists vol_min numeric, add column if not exists vol_max numeric;
update public.bew_waermepumpe set vol_min = 20, vol_max = 35 where modell = 'Silence 30 MSRC 110';
update public.bew_waermepumpe set vol_min = 25, vol_max = 45 where modell = 'Silence 30 MSRC 120';
update public.bew_waermepumpe set vol_min = 30, vol_max = 55 where modell = 'Silence 30 MSRC 150';
update public.bew_waermepumpe set vol_min = 35, vol_max = 65 where modell = 'Silence 30 MSRC 180';
