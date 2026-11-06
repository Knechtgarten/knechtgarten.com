-- Zoll (BAZG → PEAX): Veranlagungsverfügungen sammeln und an die Spediteur-Rechnung in PEAX hängen.
-- Quelle vorerst Mails an zoll@knechtgarten.ch (e-dec-web, weitergeleitete Verfügungen), später Passar-API.
-- Das Anhängen macht die Browser-Erweiterung in PEAX (über die Edge Function «zoll»).

create table if not exists zoll_evv (
  id uuid primary key default gen_random_uuid(),
  zanr text,                         -- Zollanmeldungsnummer, z. B. 26CHEI004553564035
  art text not null default 'mwst',  -- 'mwst' | 'zoll' | 'unbekannt'
  quelle text not null default 'mail',  -- 'mail' | 'passar'
  dateiname text,
  storage_pfad text not null,
  gmail_id text,
  status text not null default 'neu',   -- 'neu' | 'angehaengt' | 'mehrdeutig' | 'ohne_nummer' | 'ignoriert'
  peax_doc_id text, peax_titel text,
  angehaengt_am timestamptz, angehaengt_von text,
  in_arbeit_bis timestamptz,         -- Riegel: wer gerade anhängt (gegen Doppelarbeit)
  versuche int not null default 0, letzter_versuch timestamptz, hinweis text,
  erstellt_am timestamptz not null default now()
);
create index if not exists zoll_evv_status on zoll_evv(status);
create index if not exists zoll_evv_zanr on zoll_evv(zanr);
alter table zoll_evv enable row level security;
drop policy if exists zoll_evv_lesen on zoll_evv;
create policy zoll_evv_lesen on zoll_evv for select to authenticated using (ist_buero_oder_admin());
drop policy if exists zoll_evv_aendern on zoll_evv;
create policy zoll_evv_aendern on zoll_evv for update to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- verarbeitete Mails an zoll@ (nie doppelt), nur serverseitig
create table if not exists zoll_mail (
  gmail_id text primary key, von text, betreff text, status text not null, fehler text,
  erstellt_am timestamptz not null default now()
);
alter table zoll_mail enable row level security;

-- Ablage der PDFs (privat)
insert into storage.buckets (id, name, public) values ('zoll', 'zoll', false) on conflict (id) do nothing;
drop policy if exists zoll_dateien_lesen on storage.objects;
create policy zoll_dateien_lesen on storage.objects for select to authenticated using (bucket_id = 'zoll' and ist_buero_oder_admin());

-- Abruf der Mails alle 5 Minuten
select cron.unschedule('zoll-mail') where exists (select 1 from cron.job where jobname = 'zoll-mail');
select cron.schedule('zoll-mail', '*/5 * * * *', $$
  select net.http_post(
    url := 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/zoll',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{"aktion":"abruf"}'::jsonb, timeout_milliseconds := 60000);
$$);
