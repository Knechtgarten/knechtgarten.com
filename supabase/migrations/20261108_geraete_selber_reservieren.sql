-- Geräte selber reservieren (zuerst Transportanhänger BE-597017): Handy-Seite «Reservieren» und Planer.
-- Wer das Recht «plan / reservieren» hat, reserviert auf die eigene Planer-Zeile; ändern/löschen nur eigene. Büro/Admin alles.
alter table planer_ressource add column if not exists selbst_reservierbar boolean not null default false;
update planer_ressource set selbst_reservierbar = true where nummer = 'BE-597017';

-- Eigene Reservationen (nur Geräte mit Haken, nur auf die eigene Planer-Zeile, nur mit Recht)
create or replace function public.planer_eigene_reservation(p_ressource uuid, p_person uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select ist_eingeloggter_benutzer()
    and recht_darf('plan', 'reservieren', 'an')
    and exists (select 1 from planer_ressource r where r.id = p_ressource and r.selbst_reservierbar)
    and exists (select 1 from planer_person pp where pp.id = p_person and pp.benutzer_id = auth.uid() and pp.aktiv);
$$;
drop policy if exists planer_res_einsatz_selbst on planer_ressource_einsatz;
create policy planer_res_einsatz_selbst on planer_ressource_einsatz for all to authenticated
  using (einsatz_id is null and planer_eigene_reservation(ressource_id, person_id))
  with check (einsatz_id is null and art = 'zuteilung' and planer_eigene_reservation(ressource_id, person_id));

-- Keine Doppelbelegung bei selber reservierbaren Geräten
create or replace function public.planer_reservation_frei() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare wer text;
begin
  if new.art <> 'zuteilung' or new.beginn is null or not exists (select 1 from planer_ressource r where r.id = new.ressource_id and r.selbst_reservierbar) then return new; end if;
  select pp.name into wer from planer_ressource_einsatz e left join planer_person pp on pp.id = e.person_id
   where e.ressource_id = new.ressource_id and e.id <> new.id and e.art = 'zuteilung' and e.beginn < new.ende and e.ende > new.beginn limit 1;
  if found then raise exception 'Schon reserviert von %', coalesce(wer, 'jemand anderem') using errcode = 'P0001'; end if;
  return new;
end $$;
drop trigger if exists planer_reservation_frei on planer_ressource_einsatz;
create trigger planer_reservation_frei before insert or update on planer_ressource_einsatz for each row execute function planer_reservation_frei();

-- Recht ein für alle Gruppen ausser Hilfsarbeitende, Temporär, Schnupper (Administrator darf ohnehin alles)
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'plan', 'reservieren', 'an', case when g.name in ('Hilfsarbeitende', 'Temporär', 'Schnupper') then 'N' else 'J' end from recht_gruppe g where not g.ist_admin
on conflict (gruppe_id, tool_key, bereich_key, aktion) do update set wert = excluded.wert;

-- Handynummer einer Planer-Person (für «WhatsApp an …» beim Reservieren); nur Nummer, nur für angemeldete Mitarbeitende
create or replace function public.planer_person_telefon(p uuid) returns text language sql stable security definer set search_path to 'public' as $$
  select b.telefon from planer_person pp join benutzer b on b.id = pp.benutzer_id where pp.id = p and ist_eingeloggter_benutzer();
$$;
grant execute on function public.planer_person_telefon(uuid) to authenticated;
