-- Pflege-Vorschläge im Vorrat: von Hand hingelegte Lage (Zeile + Start in Arbeitstagen) bleibt (2026-11-28)
alter table public.planer_vorschlag_notiz add column if not exists zeile integer;
alter table public.planer_vorschlag_notiz add column if not exists start numeric;
