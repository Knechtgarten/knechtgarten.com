-- Standardarbeit lässt sich nicht löschen, solange sie bei einem Kunden hinterlegt ist (vorher: Kaskade). 2026-11-27
alter table public.pflege_kunde_arbeit drop constraint if exists pflege_kunde_arbeit_arbeit_id_fkey;
alter table public.pflege_kunde_arbeit add constraint pflege_kunde_arbeit_arbeit_id_fkey foreign key (arbeit_id) references public.pflege_arbeit(id) on delete restrict;
select confdeltype from pg_constraint where conname = 'pflege_kunde_arbeit_arbeit_id_fkey';
