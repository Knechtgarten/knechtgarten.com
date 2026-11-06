-- Pendenzen per Mail: vorname.pendenzen@knechtgarten.ch (Alias am Konto mail@knechtgarten.ch)
-- → Pendenz in der Liste «Mails» des Boards (Kürzel = pendenz_board.mail_kuerzel). Abruf alle 2 Minuten über Gmail.

-- verarbeitete Mails (damit keines doppelt kommt), nur serverseitig lesbar
create table if not exists pendenz_mail (
  gmail_id text primary key,
  pendenz_id uuid references pendenz(id) on delete set null,
  an text, von text, betreff text,
  status text not null,              -- 'ok' | 'abgelehnt' (fremder Absender) | 'fehler'
  fehler text,
  erstellt_am timestamptz not null default now()
);
alter table pendenz_mail enable row level security;

-- Kürzel der persönlichen Boards = Vorname (stefan.pendenzen@…, pascal.pendenzen@…)
update pendenz_board b set mail_kuerzel = lower(split_part(u.anzeigename, ' ', 1))
from benutzer u where b.besitzer_id = u.id and b.typ = 'person' and b.mail_kuerzel is null and u.anzeigename is not null;

-- Abruf alle 2 Minuten
select cron.unschedule('pendenzen-mail') where exists (select 1 from cron.job where jobname = 'pendenzen-mail');
select cron.schedule('pendenzen-mail', '*/2 * * * *', $$
  select net.http_post(
    url := 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/pendenzen-mail',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{}'::jsonb, timeout_milliseconds := 60000);
$$);
