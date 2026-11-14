-- 83 ältere Offerten (vor dem 3.11.2026 ohne erstellt_von) gehören Stefan (Entscheid Stefan 14.11.2026)
update public.offerte set erstellt_von = (select id from public.benutzer where anzeigename = 'Stefan' limit 1)
where erstellt_von is null and exists (select 1 from public.benutzer where anzeigename = 'Stefan');
