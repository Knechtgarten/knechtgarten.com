-- Nächtlicher Easybill-Abgleich: jede Nacht um 01:00 UTC (02:00 Winterzeit / 03:00 Sommerzeit)
-- ruft pg_cron über pg_net die Edge Function easybill-abgleich mit modus 'nacht' auf.
-- Das Token steht im Vault (Name easybill_abgleich_token) und als Function-Secret EASYBILL_ABGLEICH_TOKEN,
-- es wurde einmalig von Hand gesetzt und steht bewusst nicht in dieser Datei.
create extension if not exists pg_cron;
create extension if not exists pg_net;

select cron.unschedule('easybill-abgleich-nacht') where exists (select 1 from cron.job where jobname = 'easybill-abgleich-nacht');
select cron.schedule('easybill-abgleich-nacht', '0 1 * * *', $$
  select net.http_post(
    url := 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/easybill-abgleich',
    headers := jsonb_build_object('Content-Type', 'application/json',
      'x-abgleich-token', (select decrypted_secret from vault.decrypted_secrets where name = 'easybill_abgleich_token')),
    body := '{"modus":"nacht"}'::jsonb,
    timeout_milliseconds := 150000
  );
$$);
