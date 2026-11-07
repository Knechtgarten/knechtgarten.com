alter table public.bewilligung add column if not exists dateien jsonb not null default '{}'::jsonb;  -- hochgeladene Pläne {situation|projekt|umgebung: {pfad, name, am}} (Bucket bew-unterlagen)
