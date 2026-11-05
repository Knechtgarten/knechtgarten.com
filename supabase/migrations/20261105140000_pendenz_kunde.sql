-- Pendenzen-Tool: Offerten-Karten kennen den Kunden (schon beim Erfassen der Offerte)
alter table public.pendenz add column if not exists kunde_id uuid references public.kunde(id) on delete set null;
create index if not exists pendenz_kunde on public.pendenz (kunde_id);
