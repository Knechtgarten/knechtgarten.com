-- ============================================================================
-- Benutzer ohne Login («Person ohne Login», z.B. fuer «Zustaendig» im Pflege-Tool)
--
-- Bisher brauchte jede Zeile in benutzer ein Supabase-Login (Fremdschluessel auf
-- auth.users). Neu duerfen Platzhalter ohne Login existieren (ist_platzhalter).
-- Registriert sich spaeter jemand mit derselben E-Mail, wird der Platzhalter
-- automatisch zum echten Benutzer: seine id wird auf die Login-id umgeschrieben,
-- alle Zuordnungen (Zustaendig usw.) ziehen per ON UPDATE CASCADE mit.
-- Ein Platzhalter kann sich nie anmelden (keine Login-id, auth.uid() passt nie).
-- ============================================================================

alter table benutzer add column if not exists ist_platzhalter boolean not null default false;
alter table benutzer alter column email drop not null;
alter table benutzer add constraint benutzer_email_ohne_platzhalter
  check (ist_platzhalter or email is not null);

-- Fremdschluessel auf auth.users entfernen (sonst keine Platzhalter moeglich).
-- Das bisherige ON DELETE CASCADE uebernimmt der Trigger unten.
alter table benutzer drop constraint if exists benutzer_id_fkey;

create or replace function handle_deleted_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.benutzer where id = old.id;
  return old;
end;
$$;
drop trigger if exists on_auth_user_deleted on auth.users;
create trigger on_auth_user_deleted
  after delete on auth.users
  for each row execute function handle_deleted_auth_user();

-- Neue Registrierung: passenden Platzhalter (gleiche E-Mail) uebernehmen, sonst wie bisher
create or replace function handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.benutzer
     set id = new.id, email = new.email, ist_platzhalter = false
   where ist_platzhalter and email is not null and lower(email) = lower(new.email);
  if not found then
    insert into public.benutzer (id, email, rolle)
    values (new.id, new.email, null)
    on conflict (id) do nothing;
  end if;
  return new;
end;
$$;

-- Zuordnungen ziehen beim Umschreiben der id mit
alter table pflege_kunde_kategorie_zustaendig drop constraint pflege_kunde_kategorie_zustaendig_benutzer_id_fkey;
alter table pflege_kunde_kategorie_zustaendig add constraint pflege_kunde_kategorie_zustaendig_benutzer_id_fkey
  foreign key (benutzer_id) references benutzer(id) on delete cascade on update cascade;
alter table pflege_einsatz_status drop constraint pflege_einsatz_status_erledigt_von_fkey;
alter table pflege_einsatz_status add constraint pflege_einsatz_status_erledigt_von_fkey
  foreign key (erledigt_von) references benutzer(id) on delete set null on update cascade;
alter table pflege_foto drop constraint pflege_foto_erstellt_von_fkey;
alter table pflege_foto add constraint pflege_foto_erstellt_von_fkey
  foreign key (erstellt_von) references benutzer(id) on delete set null on update cascade;
