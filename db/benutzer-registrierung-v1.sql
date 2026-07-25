-- ============================================================================
-- Offertentool 2027 - Selbst-Registrierung mit Admin-Freischaltung.
--
-- Bisher musste ein Admin jeden Benutzer manuell im Supabase-Dashboard
-- anlegen UND danach hier per Hand einen benutzer-Eintrag mit Rolle
-- erstellen. Neu: ein Mitarbeiter kann sich selbst per E-Mail/Passwort
-- registrieren - der Trigger unten legt automatisch einen (noch rollenlosen)
-- benutzer-Eintrag an. Ohne zugewiesene Rolle bleibt der Zugriff weiterhin
-- komplett gesperrt (ist_eingeloggter_benutzer() prueft das explizit) - ein
-- Admin muss die Registrierung in der Benutzerverwaltung erst mit einer
-- Rolle freischalten.
-- ============================================================================

alter table benutzer alter column rolle drop not null;

create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.benutzer (id, email, rolle)
  values (new.id, new.email, null)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_auth_user();

create or replace function ist_eingeloggter_benutzer()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle is not null);
$$;
