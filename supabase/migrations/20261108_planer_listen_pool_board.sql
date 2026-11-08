-- Planer-Listen in den Pendenzen-Boards: Magazin (Kurz/Mittel/Lang), Vorrat einer Planer-Gruppe, offene Aufträge einer Person.
-- Normale Listen (frei verschiebbar), Inhalt kommt direkt aus dem Einsatzplaner (keine Kopie).
alter table pendenz_liste add column if not exists quelle_wert text; -- Magazin: kurz|mittel|lang · Vorrat: vorrat_bereich · Offen: planer_person.id
insert into pendenz_art (id, titel, icon, farbe, sortierung, funktion, aktiv) values
  ('pl_magazin', 'Magazin', 'ebenen', '#2A7570', 90, true, true),
  ('pl_vorrat', 'Vorrat', 'plan', '#2A7570', 91, true, true),
  ('pl_offen', 'Offene Aufträge', 'plan', '#4F8A8B', 92, true, true)
on conflict (id) do nothing;

-- Büro-Board: Magazin als drei Listen
insert into pendenz_liste (board_id, art_id, titel, bereich, x, y, quelle_wert)
select 'c99258c6-119d-4c67-9560-d1ba8c0e9388', 'pl_magazin', t, 'mitte', 20, y, k
from (values ('kurz', 'Magazin Kurz', 20), ('mittel', 'Magazin Mittel', 180), ('lang', 'Magazin Lang', 340)) v(k, t, y)
where not exists (select 1 from pendenz_liste where board_id = 'c99258c6-119d-4c67-9560-d1ba8c0e9388' and art_id = 'pl_magazin' and quelle_wert = v.k);

-- Pool-Board: Stefan, Fabian Oberholzer, Marco
do $$ declare b uuid; begin
  select id into b from pendenz_board where typ = 'gemeinsam' and name = 'Pool';
  if b is null then insert into pendenz_board (name, typ) values ('Pool', 'gemeinsam') returning id into b; end if;
  insert into pendenz_board_mitglied (board_id, benutzer_id) values
    (b, '59840bbb-c123-4d85-9b75-0c171a35ec9f'), (b, '6b59611a-6065-4578-b12a-204923545e39'), (b, '54ebd42b-47ec-4dc7-aee1-21e728b1a6a9')
  on conflict do nothing;
  if not exists (select 1 from pendenz_liste where board_id = b) then
    insert into pendenz_liste (board_id, art_id, titel, bereich, x, y, quelle_wert) values
      (b, 'pl_vorrat', 'Vorrat Pool', 'mitte', 20, 20, 'pool'),
      (b, 'pl_offen', 'Offen Marco', 'mitte', 400, 20, 'e3ea4b1c-4a4d-4cc5-a50e-540f14a54c85'),
      (b, 'besprechen', 'Zu besprechen', 'mitte', 780, 20, null),
      (b, 'bestellungen', 'Material / Bestellen', 'mitte', 780, 240, null),
      (b, 'allgemein', 'Irgendwann', 'mitte', 400, 300, null);
  end if;
end $$;

-- Protokoll: wer hat im Magazin, Vorrat oder bei offenen Aufträgen etwas eingetragen, erledigt, abgemacht oder gelöscht
create table if not exists planer_protokoll (
  id uuid primary key default gen_random_uuid(),
  tabelle text not null, eintrag_id uuid not null, aktion text not null,
  titel text, quelle_wert text, wer uuid default auth.uid(), wann timestamptz not null default now(), daten jsonb);
create index if not exists planer_protokoll_wann on planer_protokoll (wann desc);
alter table planer_protokoll enable row level security;
drop policy if exists planer_protokoll_lesen on planer_protokoll;
create policy planer_protokoll_lesen on planer_protokoll for select to authenticated using (ist_eingeloggter_benutzer());

create or replace function public.planer_protokollieren() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare r jsonb := to_jsonb(coalesce(new, old)); a text; t text; q text;
begin
  if tg_table_name = 'planer_einsatz' then
    -- nur offene (noch nicht abgemachte) Aufträge
    if tg_op = 'INSERT' and new.abgemacht then return new; end if;
    if tg_op = 'DELETE' and old.abgemacht then return old; end if;
    if tg_op = 'UPDATE' and not (old.abgemacht = false and new.abgemacht = true) then return new; end if;
    a := case tg_op when 'INSERT' then 'erfasst' when 'DELETE' then 'gelöscht' else 'abgemacht' end;
    q := coalesce(new.person_id, old.person_id)::text;
    t := coalesce((select coalesce(k.firma, k.name) from kunde k where k.id = coalesce(new.kunde_id, old.kunde_id)), r->>'titel');
  elsif tg_table_name = 'planer_magazin' then
    if tg_op = 'UPDATE' and not (old.erledigt_am is distinct from new.erledigt_am) then return new; end if;
    a := case tg_op when 'INSERT' then 'erfasst' when 'DELETE' then 'gelöscht' else case when new.erledigt_am is null then 'zurückgeholt' else 'erledigt' end end;
    q := r->>'dauer'; t := r->>'titel';
  else -- planer_vorrat
    if tg_op = 'UPDATE' then return new; end if;
    a := case tg_op when 'INSERT' then 'erfasst' else 'gelöscht' end;
    q := r->>'bereich';
    t := coalesce((select coalesce(k.firma, k.name) from kunde k where k.id = (r->>'kunde_id')::uuid), r->>'titel');
  end if;
  insert into planer_protokoll (tabelle, eintrag_id, aktion, titel, quelle_wert, daten) values (tg_table_name, (r->>'id')::uuid, a, t, q, r);
  return coalesce(new, old);
end $$;
drop trigger if exists planer_protokoll on planer_einsatz;
create trigger planer_protokoll after insert or update or delete on planer_einsatz for each row execute function planer_protokollieren();
drop trigger if exists planer_protokoll on planer_magazin;
create trigger planer_protokoll after insert or update or delete on planer_magazin for each row execute function planer_protokollieren();
drop trigger if exists planer_protokoll on planer_vorrat;
create trigger planer_protokoll after insert or delete on planer_vorrat for each row execute function planer_protokollieren();
