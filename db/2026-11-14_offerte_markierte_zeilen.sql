-- Leuchtstift: markierte Zeilen einer Offerte (Schlüssel tr[data-sk]), nur solange «Noch offen» etwas enthält
alter table public.offerte add column if not exists markierte_zeilen jsonb;
