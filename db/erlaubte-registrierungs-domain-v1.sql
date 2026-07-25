-- ============================================================================
-- Offertentool 2027 - Erlaubte E-Mail-Domains fuer Selbstregistrierung
--
-- Verhindert Spam-Registrierungen (Wegwerf-/Zufallsdomains fuellen sonst die
-- "Wartet"-Liste in der Verwaltung), ohne echte Mitarbeiter mit ihren
-- unterschiedlichen privaten E-Mail-Anbietern auszusperren. Die Liste ist
-- als admin-editierbare Tabelle angelegt (nicht hartcodiert), damit spaeter
-- ohne neue Migration weitere Domains ergaenzt werden koennen.
--
-- Achtung: Der Check greift als "before insert"-Trigger auf auth.users -
-- das betrifft JEDE neue Auth-Kontoerstellung, auch eine manuelle Anlage
-- durch einen Admin im Supabase-Dashboard (Authentication -> Users -> Add
-- User), nicht nur die Selbstregistrierung ueber das Tool. Fuer einen
-- seltenen Einzelfall mit einer noch nicht gelisteten Domain muss die
-- Domain also zuerst hier ergaenzt werden, bevor der Account angelegt wird.
-- ============================================================================

create table erlaubte_registrierungs_domain (
  domain text primary key,
  erstellt_am timestamptz not null default now()
);

alter table erlaubte_registrierungs_domain enable row level security;
create policy erlaubte_registrierungs_domain_lesen on erlaubte_registrierungs_domain
  for select using (ist_eingeloggter_benutzer());
create policy erlaubte_registrierungs_domain_admin on erlaubte_registrierungs_domain
  for all using (ist_admin()) with check (ist_admin());

insert into erlaubte_registrierungs_domain (domain) values
  ('knechtgarten.ch'),
  ('vivabalance.ch'),
  ('gmail.com'),
  ('bluewin.ch'),
  ('hotmail.com'),
  ('outlook.com'),
  ('icloud.com')
on conflict (domain) do nothing;

create or replace function pruefe_erlaubte_email_domain()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  domain_teil text;
begin
  domain_teil := lower(split_part(new.email, '@', 2));
  if not exists (select 1 from erlaubte_registrierungs_domain where domain = domain_teil) then
    raise exception 'Diese E-Mail-Domain ist fuer die Registrierung nicht zugelassen.';
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_domain_check on auth.users;
create trigger on_auth_user_domain_check
  before insert on auth.users
  for each row execute function pruefe_erlaubte_email_domain();
