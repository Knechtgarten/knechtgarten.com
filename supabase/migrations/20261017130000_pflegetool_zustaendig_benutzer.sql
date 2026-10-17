-- ============================================================================
-- Pflege-Tool: «Zustaendig» verweist auf die bestehende Tabelle benutzer
--
-- Ersetzt die eigene Liste pflege_mitarbeiter aus 20261017120000 (Nutzer-
-- Entscheid 2026-10-17): Service-Mitarbeiter werden als Benutzer gefuehrt
-- (Rolle z.B. service_team), Techniker bekommen in Etappe 6 ohnehin einen Login.
--
-- benutzer ist per RLS nur fuer Admin lesbar. Damit Buero-Team und Techniker
-- die Auswahl trotzdem sehen, liefert pflege_zustaendige() nur id/email/rolle
-- der aktiven Benutzer (security definer, nur fuer eingeloggte).
-- ============================================================================

drop table if exists pflege_kunde_kategorie_zustaendig;
drop table if exists pflege_mitarbeiter;

create table pflege_kunde_kategorie_zustaendig (
  kunde_kategorie_id uuid not null references pflege_kunde_kategorie(id) on delete cascade,
  benutzer_id uuid not null references benutzer(id) on delete cascade,
  primary key (kunde_kategorie_id, benutzer_id)
);
alter table pflege_kunde_kategorie_zustaendig enable row level security;
create policy pflege_kunde_kategorie_zustaendig_voller_zugriff on pflege_kunde_kategorie_zustaendig
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

create or replace function pflege_zustaendige()
returns table (id uuid, email text, rolle text)
language sql
security definer
stable
set search_path = public
as $$
  select b.id, b.email, b.rolle
  from benutzer b
  where ist_eingeloggter_benutzer() and b.aktiv and b.rolle is not null
  order by b.email;
$$;
revoke all on function pflege_zustaendige() from public, anon;
grant execute on function pflege_zustaendige() to authenticated;
