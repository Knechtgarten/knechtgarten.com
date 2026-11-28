-- Verlauf auch für die Pflegekarte (bereich 'pflege', bezug = kunde_id). 2026-11-28
-- 'eltern:<tabelle>:<spalte>[:<zielspalte>]' – Zielspalte im Elterndatensatz (Standard offerte_id)
create or replace function public.verlauf_schreiben() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare r jsonb := to_jsonb(coalesce(new, old)); b uuid; q text := tg_argv[1]; teile text[];
begin
  if tg_op = 'UPDATE' and to_jsonb(old) = to_jsonb(new) then return new; end if;
  if q is not null then
    if q like 'eltern:%' then
      teile := string_to_array(q, ':');
      execute format('select %I from public.%I where id = $1', coalesce(teile[4], 'offerte_id'), teile[2]) into b using (r->>teile[3])::uuid;
    else b := (r->>q)::uuid; end if;
  end if;
  insert into public.verlauf (bereich, bezug_id, tabelle, datensatz_id, aktion, alt, neu, rueck)
  values (tg_argv[0], b, tg_table_name, (r->>'id')::uuid, left(tg_op, 1),
    case when tg_op <> 'INSERT' then to_jsonb(old) end, case when tg_op <> 'DELETE' then to_jsonb(new) end,
    coalesce(current_setting('kg.rueck', true), '') = '1');
  return coalesce(new, old);
end $$;

drop trigger if exists verlauf on public.pflege_kunde_kategorie;
create trigger verlauf after insert or update or delete on public.pflege_kunde_kategorie for each row execute function verlauf_schreiben('pflege', 'kunde_id');
drop trigger if exists verlauf on public.pflege_kunde_arbeit;
create trigger verlauf after insert or update or delete on public.pflege_kunde_arbeit for each row execute function verlauf_schreiben('pflege', 'eltern:pflege_kunde_kategorie:kunde_kategorie_id:kunde_id');
