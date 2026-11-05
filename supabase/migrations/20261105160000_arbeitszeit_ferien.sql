-- Einsatzplaner: Arbeitszeit & Ferien (Einstellungen) - wiederkehrende Ferien pro Kalenderwoche + Ausnahmen pro Jahr
alter table public.planer_arbeitszeit add column if not exists ende text not null default '17:00';
alter table public.planer_arbeitszeit add column if not exists mittag numeric not null default 1;

create table if not exists public.planer_ferien (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  art text not null default 'betrieb' check (art in ('betrieb', 'lernende', 'andere')),
  von_kw int not null check (von_kw between 1 and 53),
  bis_kw int not null check (bis_kw between 1 and 53),
  sortierung int not null default 0,
  erstellt_am timestamptz not null default now()
);
create table if not exists public.planer_ferien_ausnahme (
  id uuid primary key default gen_random_uuid(),
  ferien_id uuid not null references public.planer_ferien(id) on delete cascade,
  jahr int not null,
  von date,
  bis date,
  weg boolean not null default false,
  unique (ferien_id, jahr)
);
alter table public.planer_ferien enable row level security;
alter table public.planer_ferien_ausnahme enable row level security;
drop policy if exists planer_ferien_lesen on public.planer_ferien;
create policy planer_ferien_lesen on public.planer_ferien for select using (ist_eingeloggter_benutzer());
drop policy if exists planer_ferien_buero on public.planer_ferien;
create policy planer_ferien_buero on public.planer_ferien for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());
drop policy if exists planer_ferien_ausnahme_lesen on public.planer_ferien_ausnahme;
create policy planer_ferien_ausnahme_lesen on public.planer_ferien_ausnahme for select using (ist_eingeloggter_benutzer());
drop policy if exists planer_ferien_ausnahme_buero on public.planer_ferien_ausnahme;
create policy planer_ferien_ausnahme_buero on public.planer_ferien_ausnahme for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Zeilen unter «Allgemein»: Hinweise -> Termine & Infos, Lehrlinge -> Arbeitszeit & Ferien
update public.planer_person p set name = 'Termine & Infos' from public.planer_gruppe g where g.id = p.gruppe_id and g.name = 'Allgemein' and p.name = 'Hinweise';
update public.planer_person p set name = 'Arbeitszeit & Ferien' from public.planer_gruppe g where g.id = p.gruppe_id and g.name = 'Allgemein' and p.name = 'Lehrlinge';
