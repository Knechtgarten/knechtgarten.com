-- Pendenzen auf einen Tag legen (Drehrad) + Sammeltermin im eigenen Google-Kalender «Pendenzen» (05:00–15:00)
alter table public.pendenz add column if not exists datum date;          -- Tag, an dem die Pendenz erledigt werden soll
alter table public.pendenz add column if not exists datum_seit date;     -- erstes Datum, falls sie schon mitgewandert ist («seit …»)
create index if not exists pendenz_datum_idx on public.pendenz(datum) where datum is not null and erledigt = false;

-- Kalender «Pendenzen» pro Person
create table if not exists public.pendenz_kalender_konto (
  benutzer_id uuid primary key references public.benutzer(id) on delete cascade,
  calendar_id text not null,
  erstellt_am timestamptz not null default now()
);
-- ein Sammeltermin pro Person und Tag
create table if not exists public.pendenz_kalender_tag (
  benutzer_id uuid not null references public.benutzer(id) on delete cascade,
  tag date not null,
  event_id text not null,
  start_ts text, ende_ts text,         -- zuletzt bekannte Zeit (zum Erkennen, ob in Google verschoben/verlängert)
  manuell boolean not null default false,
  inhalt_hash text,
  geaendert_am timestamptz not null default now(),
  primary key (benutzer_id, tag)
);
alter table public.pendenz_kalender_konto enable row level security;
alter table public.pendenz_kalender_tag enable row level security;
drop policy if exists pkk_eigen on public.pendenz_kalender_konto;
create policy pkk_eigen on public.pendenz_kalender_konto for select using (benutzer_id = auth.uid());
drop policy if exists pkt_eigen on public.pendenz_kalender_tag;
create policy pkt_eigen on public.pendenz_kalender_tag for select using (benutzer_id = auth.uid());

-- Status für die Knöpfe im Tool (Gmail-Stern, Google-Kalender)
create or replace function public.gmail_stern_status() returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'verbunden', coalesce((select scope like '%gmail.modify%' from google_verbindung where benutzer_id = auth.uid()), false),
    'kalender', coalesce((select scope like '%auth/calendar%' from google_verbindung where benutzer_id = auth.uid()), false),
    'aktiv', exists(select 1 from pendenz_mail where status like 'stern%'));
$$;
revoke all on function public.gmail_stern_status() from public, anon;
grant execute on function public.gmail_stern_status() to authenticated;

-- alle 2 Minuten abgleichen (Mitwandern über Nacht passiert im ersten Lauf nach Mitternacht)
select cron.unschedule('pendenzen-kalender') where exists (select 1 from cron.job where jobname = 'pendenzen-kalender');
select cron.schedule('pendenzen-kalender', '1-59/2 * * * *', $$
  select net.http_post(url := 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/pendenzen-kalender',
    headers := jsonb_build_object('Content-Type', 'application/json'), body := '{}'::jsonb, timeout_milliseconds := 60000); $$);
select count(*) from cron.job where jobname = 'pendenzen-kalender';
