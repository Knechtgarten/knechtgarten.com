-- Zoll: Passar-Verfügungen direkt beim BAZG abholen (B2B Hub Chartera Output, API charteraoutput_documents v4)
-- Zugang aus dem API-Selfservice-Portal (Anwendung prod_knechtgartenzoll-pams_1000968596): Key, Secret, Refresh Token.
-- Der Refresh Token gilt 7 Tage und wird bei jedem Refresh ersetzt → die Edge Function «zoll» erneuert ihn mehrmals täglich.
-- Zugangsdaten nur serverseitig (keine Policies); Eintragen nur über zoll_passar_setzen (Admin), lesen nur den Status.

create table if not exists zoll_passar (
  id int primary key default 1 check (id = 1),
  bp_id text not null default '1000968596',
  client_key text, client_secret text,
  refresh_token text, refresh_bis timestamptz,
  access_token text, access_bis timestamptz, access_von timestamptz,
  letzte_message_id text,            -- Lesezeiger im B2B Hub (lastMessageId)
  letzter_abruf timestamptz, letzter_fehler text, fehler_seit timestamptz,
  geaendert_am timestamptz not null default now(), geaendert_von text
);
alter table zoll_passar enable row level security;

create or replace function zoll_passar_setzen(p_key text, p_secret text, p_refresh text, p_access text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not ist_admin() then raise exception 'Nur Admin'; end if;
  if coalesce(trim(p_key), '') = '' or coalesce(trim(p_secret), '') = '' or coalesce(trim(p_refresh), '') = '' then
    raise exception 'Key, Secret und Refresh Token sind nötig.'; end if;
  insert into zoll_passar (id) values (1) on conflict (id) do nothing;
  update zoll_passar set client_key = trim(p_key), client_secret = trim(p_secret), refresh_token = trim(p_refresh),
    refresh_bis = now() + interval '7 days',
    access_token = nullif(trim(coalesce(p_access, '')), ''), access_bis = case when coalesce(trim(p_access), '') <> '' then now() + interval '23 hours' end,
    access_von = case when coalesce(trim(p_access), '') <> '' then now() end,
    letzter_fehler = null, fehler_seit = null, geaendert_am = now(),
    geaendert_von = (select email from benutzer where id = auth.uid())
  where id = 1;
end $$;
revoke all on function zoll_passar_setzen(text, text, text, text) from public, anon;
grant execute on function zoll_passar_setzen(text, text, text, text) to authenticated;

-- Status ohne Geheimnisse (für die Zoll-Seite)
create or replace function zoll_passar_status()
returns table (verbunden boolean, refresh_bis timestamptz, letzter_abruf timestamptz, letzter_fehler text, fehler_seit timestamptz, geaendert_am timestamptz, geaendert_von text)
language sql security definer set search_path = public stable as $$
  select p.refresh_token is not null, p.refresh_bis, p.letzter_abruf, p.letzter_fehler, p.fehler_seit, p.geaendert_am, p.geaendert_von
  from zoll_passar p where p.id = 1 and ist_buero_oder_admin();
$$;
revoke all on function zoll_passar_status() from public, anon;
grant execute on function zoll_passar_status() to authenticated;

-- Abruf alle 2 Std. zu krummer Minute (BAZG: keine festen Uhrzeiten, Token-Refresh 3–4× täglich macht die Function selbst)
select cron.unschedule('zoll-passar') where exists (select 1 from cron.job where jobname = 'zoll-passar');
select cron.schedule('zoll-passar', '37 */2 * * *', $$
  select net.http_post(
    url := 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/zoll',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{"aktion":"passar"}'::jsonb, timeout_milliseconds := 140000);
$$);
