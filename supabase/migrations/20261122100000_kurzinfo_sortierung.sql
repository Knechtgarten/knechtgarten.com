-- Kurzinfos im Spickzettel per Ziehen sortierbar (gilt allgemein für Einträge, bisher ohne Reihenfolge)
alter table public.wissen_eintrag add column if not exists sortierung integer;

-- bestehende Kurzinfos: Reihenfolge nach Titel vorbelegen
with r as (
  select e.id, row_number() over (partition by k.thema_id order by e.titel) * 10 as s
  from public.wissen_eintrag e join public.wissen_kategorie k on k.id = e.kategorie_id
  where k.art = 'kurz' and e.sortierung is null
)
update public.wissen_eintrag e set sortierung = r.s from r where r.id = e.id;

select count(*) filter (where sortierung is not null) as mit_reihenfolge from public.wissen_eintrag;
