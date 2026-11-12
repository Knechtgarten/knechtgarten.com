-- Pflege: «Anmelden» und «Fixe Woche» pro Arbeit statt Abo-Typ pro Kunde (Entscheid Stefan 2026-11-12).
-- pflege_kunde.abo_typ bleibt als abgeleiteter Wert (Listen, Filter, Handy): per Trigger aus den Arbeiten berechnet.
alter table public.pflege_kunde_arbeit add column if not exists anmelden boolean not null default true;
alter table public.pflege_kunde_arbeit add column if not exists fixe_woche boolean not null default false;
-- Übernahme: Arbeiten von Kunden «ohne Voranmeldung» brauchen keine Anmeldung, alle anderen schon
update public.pflege_kunde_arbeit a set anmelden = (pk.abo_typ <> 'ohne_voranmeldung')
  from public.pflege_kunde_kategorie kk join public.pflege_kunde pk on pk.kunde_id = kk.kunde_id
 where kk.id = a.kunde_kategorie_id;

create or replace function public.pflege_abo_typ_ableiten(p_kunde uuid) returns void language sql security definer set search_path = public as $$
  update public.pflege_kunde pk set abo_typ = case
      when exists (select 1 from public.pflege_kunde_arbeit a join public.pflege_kunde_kategorie kk on kk.id = a.kunde_kategorie_id where kk.kunde_id = p_kunde and a.anmelden) then 'mit_voranmeldung'
      when exists (select 1 from public.pflege_kunde_arbeit a join public.pflege_kunde_kategorie kk on kk.id = a.kunde_kategorie_id where kk.kunde_id = p_kunde) then 'ohne_voranmeldung'
      else 'kein_abo' end
   where pk.kunde_id = p_kunde;
$$;
create or replace function public.pflege_abo_typ_trigger() returns trigger language plpgsql security definer set search_path = public as $$
declare v_kk uuid := coalesce(new.kunde_kategorie_id, old.kunde_kategorie_id); v_kunde uuid;
begin
  select kunde_id into v_kunde from public.pflege_kunde_kategorie where id = v_kk;
  if v_kunde is not null then perform public.pflege_abo_typ_ableiten(v_kunde); end if;
  return null;
end $$;
drop trigger if exists pflege_abo_typ on public.pflege_kunde_arbeit;
create trigger pflege_abo_typ after insert or update of anmelden, kunde_kategorie_id or delete on public.pflege_kunde_arbeit
  for each row execute function public.pflege_abo_typ_trigger();
-- Kategorie gelöscht (mit ihren Arbeiten): Kunde neu ableiten
create or replace function public.pflege_abo_typ_kk_trigger() returns trigger language plpgsql security definer set search_path = public as $$
begin perform public.pflege_abo_typ_ableiten(old.kunde_id); return null; end $$;
drop trigger if exists pflege_abo_typ_kk on public.pflege_kunde_kategorie;
create trigger pflege_abo_typ_kk after delete on public.pflege_kunde_kategorie for each row execute function public.pflege_abo_typ_kk_trigger();
select public.pflege_abo_typ_ableiten(kunde_id) from public.pflege_kunde;

-- Planer: gestrichelter (nicht abgemachter) Auftrag in der oberen Zeile der Person
alter table public.planer_einsatz add column if not exists fixe_woche boolean not null default false;
