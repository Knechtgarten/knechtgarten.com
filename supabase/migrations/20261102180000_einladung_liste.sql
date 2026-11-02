-- ============================================================================
-- Registrierungs-Sperre über eine Einladungsliste statt app_metadata
-- (GoTrue setzt app_metadata beim Anlegen erst nach dem Insert – der Trigger sah «eingeladen» nicht).
-- Die Edge Function «benutzer-einladen» trägt die Adresse unmittelbar vor createUser hier ein;
-- der Trigger lässt nur eingetragene Adressen zu und entfernt den Eintrag gleich wieder.
-- Kein Zugriff vom Browser (RLS ohne Policies).
-- ============================================================================
create table if not exists benutzer_einladung (
  email text primary key,
  erstellt_am timestamptz not null default now()
);
alter table benutzer_einladung enable row level security;

create or replace function public.handle_new_auth_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if not exists (select 1 from public.benutzer_einladung where lower(email) = lower(new.email) and erstellt_am > now() - interval '10 minutes')
     and coalesce(new.raw_app_meta_data->>'eingeladen', '') <> 'true' then
    raise exception 'Registrierung nur mit Einladung. Bitte im Büro melden.';
  end if;
  delete from public.benutzer_einladung where lower(email) = lower(new.email);
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
$function$;
