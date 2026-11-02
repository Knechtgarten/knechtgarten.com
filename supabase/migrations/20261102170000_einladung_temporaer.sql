-- ============================================================================
-- Anmeldung nur noch per Einladung + temporäre Benutzer mit persönlichem Link
--  * Selbstregistrierung abgeschaltet: neue Auth-Konten nur noch über die Edge Function
--    «benutzer-einladen» (app_metadata.eingeladen = true). Bestehende Konten unverändert.
--  * Temporäre: Login ohne E-Mail/Passwort über einen persönlichen Link (Token-Hash in benutzer_zugang),
--    Auth-Konto mit Ersatz-Adresse @temp.knechtgarten.ch, Rechte-Gruppe «Temporär» (nur Planer ansehen).
--  * Planer: Gruppe «Neu» zuoberst (unter Allgemein) – neu eingeladene Personen landen dort und werden verschoben.
-- ============================================================================

-- Temporäre: Ersatz-Domain zulassen (Domain-Prüfung beim Anlegen des Auth-Kontos)
insert into erlaubte_registrierungs_domain (domain) select 'temp.knechtgarten.ch'
where not exists (select 1 from erlaubte_registrierungs_domain where domain = 'temp.knechtgarten.ch');

alter table benutzer add column if not exists ist_temporaer boolean not null default false;

-- Persönlicher Link: nur der Hash des Schlüssels, nur für die Edge Functions (RLS ohne Policies = kein Zugriff vom Browser)
create table if not exists benutzer_zugang (
  benutzer_id uuid primary key references benutzer(id) on delete cascade on update cascade,
  token_hash text not null unique,
  gesperrt boolean not null default false,
  erstellt_am timestamptz not null default now()
);
alter table benutzer_zugang enable row level security;

-- Rechte-Gruppe «Temporär»: wie Hilfsarbeitende, aber ausserhalb des Planers nichts; im Planer nur ansehen
insert into recht_gruppe (schluessel, name, bereich, ist_admin, rolle_alt, ist_standard_fuer_rolle, sortierung)
select 'temp', 'Temporär', 'aussendienst', false, 'mitarbeitende', false, 70
where not exists (select 1 from recht_gruppe where schluessel = 'temp');

insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select (select id from recht_gruppe where schluessel = 'temp'), e.tool_key, e.bereich_key, e.aktion,
  case
    when e.tool_key = 'plan' and (e.aktion in ('anzeigen', 'sichtbar')) then e.wert
    when e.wert in ('J', 'N') then 'N'
    else 'K'
  end
from recht_eintrag e
where e.gruppe_id = (select id from recht_gruppe where schluessel = 'hilf')
  and not exists (select 1 from recht_eintrag x where x.gruppe_id = (select id from recht_gruppe where schluessel = 'temp'));

-- Planer: Gruppe «Neu» direkt unter Allgemein
insert into planer_gruppe (name, sortierung) select 'Neu', 15
where not exists (select 1 from planer_gruppe where name = 'Neu');

-- Selbstregistrierung abschalten: neue Auth-Konten nur mit Einladung
create or replace function public.handle_new_auth_user()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if coalesce(new.raw_app_meta_data->>'eingeladen', '') <> 'true' then
    raise exception 'Registrierung nur mit Einladung. Bitte im Büro melden.';
  end if;
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
