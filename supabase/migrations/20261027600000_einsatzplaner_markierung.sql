-- Einsatzplaner: Markierungen (kleine runde Icons mitten im Balken bzw. in der Zeile)
-- art   kran | start | sitzung | anlass | info | pneu | aemtli
-- teil  ganz (Mitte des Tages) | vm (links) | nm (rechts)
-- text  optionaler Hinweis im Mouse-over, z. B. «Start 6:30» oder «Kran Firma Muster»
create table if not exists planer_markierung (
  id uuid primary key default gen_random_uuid(),
  person_id uuid not null references planer_person(id) on delete cascade,
  tag date not null,
  teil text not null default 'ganz' check (teil in ('ganz', 'vm', 'nm')),
  art text not null,
  text text null,
  erstellt_von uuid null,
  erstellt_am timestamptz not null default now()
);
create index if not exists planer_markierung_tag on planer_markierung(tag);
alter table planer_markierung enable row level security;
drop policy if exists planer_markierung_voll on planer_markierung;
create policy planer_markierung_voll on planer_markierung for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
