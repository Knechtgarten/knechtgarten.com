-- Neues Haupttool «CAD»: Pläne pro Kunde (optional Projekt). Zeichnung + Grundlage (Vermessung) als JSON.
create table if not exists public.cad_plan (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid references public.kunde(id) on delete cascade,
  projekt_id uuid,
  name text not null default 'Gartenplan',
  variante text,
  grundlage jsonb,                -- { e0, n0, parzelle, parzelle_nr, flaeche, haeuser[], nachbarn[], adresse, stand }
  objekte jsonb not null default '[]'::jsonb,
  einstellungen jsonb not null default '{}'::jsonb,   -- Ebenen, Massstab, Luftbild-Deckkraft …
  erstellt_von uuid default auth.uid(),
  erstellt_am timestamptz not null default now(),
  geaendert_am timestamptz not null default now()
);
create index if not exists cad_plan_kunde_idx on public.cad_plan(kunde_id);
alter table public.cad_plan enable row level security;
drop policy if exists cad_plan_alle on public.cad_plan;
create policy cad_plan_alle on public.cad_plan for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
-- Startseite: Kachel «CAD» (nur Büro)
insert into public.modul_sichtbarkeit (modul_key, name, fuer_buero_team, fuer_mitarbeitende, fuer_service_team, kurzname, icon_key, titel_mittel, hintergrund, ist_extern)
values ('cad', 'CAD', true, false, false, 'CAD', 'cad', 'CAD', 'grau', false)
on conflict (modul_key) do nothing;
select count(*) from public.cad_plan;
