-- ============================================================================
-- Pflegekarte neu (2026-11-27): nur noch 3 Kategorien, Zuständig + Notiz pro Arbeit
--   Gartenpflege <- Winterschnitt, Rasen, Solitärbaumpflege, Nematoden, Zünsler
--   Pool         <- Biopool, Fischteich, Zierbecken/Brunnen
--   Bewässerung bleibt, «Individuell» (leer) fällt weg.
-- Zuständig hängt neu an der Arbeit (pflege_kunde_arbeit.zustaendig_id).
-- Planer bündelt pro Kunde + Kategorie + Zuständigem + Woche: «buendel» = benutzer_id
-- als Text oder '-' (niemand). Status/Notiz/Einsatz tragen das Bündel mit (null = ganze Woche).
-- Alte Tabelle pflege_kunde_kategorie_zustaendig bleibt als Sicherung, wird nicht mehr benutzt.
-- ============================================================================

alter table pflege_kunde_arbeit add column if not exists zustaendig_id uuid null references benutzer(id) on delete set null;
alter table pflege_kunde_arbeit add column if not exists notiz text null;
alter table pflege_einsatz_status add column if not exists buendel text null;
alter table planer_einsatz add column if not exists pflege_buendel text null;
alter table planer_vorschlag_notiz add column if not exists buendel text null;

-- Zuständig der Kategorie auf jede Arbeit übertragen (es gibt nie mehr als eine Person pro Kategorie)
update pflege_kunde_arbeit a set zustaendig_id = z.benutzer_id
  from pflege_kunde_kategorie_zustaendig z where z.kunde_kategorie_id = a.kunde_kategorie_id;
-- Bisherige Bündel = ganze Kategorie mit ihrer Person
update pflege_einsatz_status s set buendel = coalesce((select z.benutzer_id::text from pflege_kunde_kategorie_zustaendig z where z.kunde_kategorie_id = s.kunde_kategorie_id limit 1), '-');
update planer_einsatz e set pflege_buendel = coalesce((select z.benutzer_id::text from pflege_kunde_kategorie_zustaendig z where z.kunde_kategorie_id = e.pflege_kunde_kategorie_id limit 1), '-')
  where e.pflege_kunde_kategorie_id is not null;
update planer_vorschlag_notiz v set buendel = coalesce((select z.benutzer_id::text from pflege_kunde_kategorie_zustaendig z where z.kunde_kategorie_id = v.kunde_kategorie_id limit 1), '-');

-- Schlüssel mit Bündel
alter table pflege_einsatz_status drop constraint if exists pflege_einsatz_status_pkey;
alter table pflege_einsatz_status add column if not exists id uuid not null default gen_random_uuid() primary key; -- Realtime braucht einen Schlüssel
alter table pflege_einsatz_status add constraint pflege_einsatz_status_uniq unique nulls not distinct (kunde_kategorie_id, jahr, kw, buendel);
alter table planer_vorschlag_notiz drop constraint if exists planer_vorschlag_notiz_pkey;
alter table planer_vorschlag_notiz add column if not exists id uuid not null default gen_random_uuid() primary key;
alter table planer_vorschlag_notiz add constraint planer_vorschlag_notiz_uniq unique nulls not distinct (kunde_kategorie_id, jahr, kw, buendel);

-- Kategorien zusammenlegen
create temp table kat_map on commit drop as
select alt.id alt_id, neu.id neu_id
from pflege_kategorie alt
join pflege_kategorie neu on neu.name = case
  when alt.name in ('Winterschnitt', 'Rasen', 'Solitärbaumpflege', 'Nematoden', 'Zünsler') then 'Gartenpflege'
  when alt.name in ('Biopool', 'Fischteich', 'Zierbecken/Brunnen') then 'Pool' end;

do $$
declare g record; ziel uuid; r record;
begin
  -- pro Kunde/Objekt/neuer Kategorie: Ziel = bestehende Zielkategorie, sonst die älteste
  for g in
    select kk.kunde_id, kk.objekt_id, m.neu_id neu
    from pflege_kunde_kategorie kk join kat_map m on m.alt_id = kk.kategorie_id
    group by 1, 2, 3
  loop
    select kk.id into ziel from pflege_kunde_kategorie kk
      where kk.kunde_id = g.kunde_id and kk.objekt_id is not distinct from g.objekt_id
        and (kk.kategorie_id = g.neu or kk.kategorie_id in (select alt_id from kat_map where neu_id = g.neu))
      order by (kk.kategorie_id = g.neu) desc, kk.erstellt_am limit 1;
    update pflege_kunde_kategorie set kategorie_id = g.neu where id = ziel;
    for r in
      select kk.* from pflege_kunde_kategorie kk
      where kk.kunde_id = g.kunde_id and kk.objekt_id is not distinct from g.objekt_id and kk.id <> ziel
        and kk.kategorie_id in (select alt_id from kat_map where neu_id = g.neu)
    loop
      update pflege_kunde_kategorie set werte = r.werte || werte, projektleiter = coalesce(projektleiter, r.projektleiter) where id = ziel;
      update pflege_kunde_arbeit set kunde_kategorie_id = ziel where kunde_kategorie_id = r.id;
      insert into pflege_einsatz_status (kunde_kategorie_id, jahr, kw, erledigt_am, erledigt_von, buendel)
        select ziel, jahr, kw, erledigt_am, erledigt_von, buendel from pflege_einsatz_status where kunde_kategorie_id = r.id
        on conflict do nothing;
      insert into planer_vorschlag_notiz (kunde_kategorie_id, jahr, kw, notiz, geaendert_am, projektleiter_id, buendel)
        select ziel, jahr, kw, notiz, geaendert_am, projektleiter_id, buendel from planer_vorschlag_notiz where kunde_kategorie_id = r.id
        on conflict do nothing;
      update planer_einsatz set pflege_kunde_kategorie_id = ziel where pflege_kunde_kategorie_id = r.id;
      delete from pflege_kunde_kategorie where id = r.id;
    end loop;
  end loop;
end $$;

-- Definitionen verschieben
update pflege_arbeit a set kategorie_id = m.neu_id from kat_map m where a.kategorie_id = m.alt_id;
update pflege_feld f set kategorie_id = m.neu_id, reihenfolge = f.reihenfolge + 100 from kat_map m where f.kategorie_id = m.alt_id;
insert into pflege_foto_kategorie (foto_id, kategorie_id) select x.foto_id, m.neu_id from pflege_foto_kategorie x join kat_map m on m.alt_id = x.kategorie_id on conflict do nothing;
insert into pflege_dokument_kategorie (dokument_id, kategorie_id) select x.dokument_id, m.neu_id from pflege_dokument_kategorie x join kat_map m on m.alt_id = x.kategorie_id on conflict do nothing;
delete from pflege_kategorie where id in (select alt_id from kat_map) or name = 'Individuell';
update pflege_kategorie set reihenfolge = case name when 'Gartenpflege' then 1 when 'Bewässerung' then 2 when 'Pool' then 3 else reihenfolge end;

-- Zuständigkeit übertragen (Verwaltung › Mitarbeitende): jetzt an den Arbeiten
create or replace function pflege_zustaendig_uebertragen(von uuid, an uuid)
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if not ist_buero_oder_admin() then
    raise exception 'Nur Büro-Team oder Admin dürfen Zuständigkeiten übertragen.';
  end if;
  if von = an then return 0; end if;
  update pflege_kunde_arbeit set zustaendig_id = an where zustaendig_id = von;
  get diagnostics n = row_count;
  return n;
end $$;
