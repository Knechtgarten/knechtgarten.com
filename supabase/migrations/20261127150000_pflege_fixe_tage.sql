-- Pflege-Arbeiten beim Kunden: Zeitpunkt = Standardwochen (aus den Einstellungen, beim Kunden nur ein/aus) und/oder fixe Tage (KW + Wochentag).
-- Eigene Wochen pro Kunde (kws_plus / kws_minus) gibt es nicht mehr: vorher gesichert in pflege_kunde_arbeit_alt, beim Kunden als Hinweis
-- «Bisher: KW …» mit «Als fixe Tage übernehmen» / «Verwerfen». Wunsch-Tage des Kunden entfallen (ersetzt durch fixe Tage). 2026-11-27
alter table public.pflege_kunde_arbeit add column if not exists standard_aus boolean not null default false;
alter table public.pflege_kunde_arbeit add column if not exists fixe_tage jsonb not null default '[]'::jsonb; -- [{ "kw": 17, "wt": 5 }] wt 1 = Montag … 7 = Sonntag

create table if not exists public.pflege_kunde_arbeit_alt (
  kunde_arbeit_id uuid primary key references public.pflege_kunde_arbeit(id) on delete cascade,
  wochen int[] not null,          -- Wochen, die bis 27.11.2026 galten (Standard ± Abweichung)
  kws_plus int[], kws_minus int[], kws int[],
  erledigt boolean not null default false,
  gesichert_am timestamptz not null default now()
);
alter table public.pflege_kunde_arbeit_alt enable row level security;
drop policy if exists pflege_kunde_arbeit_alt_alle on public.pflege_kunde_arbeit_alt;
create policy pflege_kunde_arbeit_alt_alle on public.pflege_kunde_arbeit_alt for all to authenticated using (true) with check (true);

insert into public.pflege_kunde_arbeit_alt (kunde_arbeit_id, wochen, kws_plus, kws_minus, kws)
select ka.id,
  coalesce((select array_agg(distinct w order by w) from unnest(
    case when ka.arbeit_id is null then coalesce(ka.kws, '{}')
    else array(select unnest(coalesce(a.standard_kws, '{}')) except select unnest(coalesce(ka.kws_minus, '{}'))) || coalesce(ka.kws_plus, '{}') end) w), '{}'),
  ka.kws_plus, ka.kws_minus, ka.kws
from public.pflege_kunde_arbeit ka left join public.pflege_arbeit a on a.id = ka.arbeit_id
where coalesce(array_length(ka.kws_plus, 1), 0) + coalesce(array_length(ka.kws_minus, 1), 0) > 0
   or (ka.arbeit_id is null and coalesce(array_length(ka.kws, 1), 0) > 0)
on conflict (kunde_arbeit_id) do nothing;

-- Wer Standard-Wochen weggeklickt hatte: Standard für diesen Kunden aus (sonst käme die weggelassene Woche zurück)
update public.pflege_kunde_arbeit set standard_aus = true where coalesce(array_length(kws_minus, 1), 0) > 0;
update public.pflege_kunde_arbeit set kws_plus = '{}', kws_minus = '{}'
  where coalesce(array_length(kws_plus, 1), 0) + coalesce(array_length(kws_minus, 1), 0) > 0;

select (select count(*) from public.pflege_kunde_arbeit_alt) gesichert,
       (select count(*) from public.pflege_kunde_arbeit where standard_aus) standard_aus;
