alter table public.bewilligung add column if not exists dok_stand jsonb;  -- [{n, ok}] Stand der Dokumente, für Kontakte › Projekte (nur lesen)
