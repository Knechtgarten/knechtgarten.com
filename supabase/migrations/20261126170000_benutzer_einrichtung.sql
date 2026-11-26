-- Einrichtungs-Link für Mitarbeitende: einrichten.html#t=<schlüssel>, die Person wählt ihr Passwort selbst.
-- Gilt 7 Tage und nur einmal; nur der Hash wird gespeichert. Nur serverseitig (Edge Functions), keine Policies.
create table if not exists public.benutzer_einrichtung (
  benutzer_id uuid primary key references public.benutzer(id) on delete cascade on update cascade,
  token_hash text not null unique,
  gueltig_bis timestamptz not null,
  erstellt_am timestamptz not null default now()
);
alter table public.benutzer_einrichtung enable row level security;
