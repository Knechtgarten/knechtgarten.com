-- Verlauf (2026-11-28): jede Änderung in Planer und Offerten wird mitgeschrieben (vorher/nachher).
-- Daraus: Zurück/Vorwärts (eigene Schritte), Verlauf-Leiste, Vorschau eines früheren Stands, Wiederherstellen.
-- Einträge älter als 90 Tage löscht ein täglicher Job.

create table if not exists public.verlauf (
  id bigserial primary key,
  zeit timestamptz not null default now(),
  benutzer_id uuid default auth.uid(),
  tx bigint not null default txid_current(),
  bereich text not null,            -- 'planer' | 'offerte'
  bezug_id uuid,                    -- bei Offerten: offerte.id
  tabelle text not null,
  datensatz_id uuid not null,
  aktion text not null,             -- 'I' | 'U' | 'D'
  alt jsonb, neu jsonb,
  rueck boolean not null default false -- entstanden durch Zurück/Vorwärts/Wiederherstellen
);
create index if not exists verlauf_bereich_id on public.verlauf (bereich, id desc);
create index if not exists verlauf_bezug_id on public.verlauf (bezug_id, id desc) where bezug_id is not null;
create index if not exists verlauf_benutzer_id on public.verlauf (benutzer_id, id desc);
create index if not exists verlauf_datensatz on public.verlauf (datensatz_id, id desc);
alter table public.verlauf enable row level security;
drop policy if exists verlauf_lesen on public.verlauf;
create policy verlauf_lesen on public.verlauf for select to authenticated using (ist_eingeloggter_benutzer());

-- Trigger: tg_argv[0] = Bereich, tg_argv[1] = woher die Offerte kommt ('id', 'offerte_id' oder 'eltern:<tabelle>:<spalte>')
create or replace function public.verlauf_schreiben() returns trigger language plpgsql security definer set search_path to 'public' as $$
declare r jsonb := to_jsonb(coalesce(new, old)); b uuid; q text := tg_argv[1]; teile text[];
begin
  if tg_op = 'UPDATE' and to_jsonb(old) = to_jsonb(new) then return new; end if;
  if q is not null then
    if q like 'eltern:%' then
      teile := string_to_array(q, ':');
      execute format('select offerte_id from public.%I where id = $1', teile[2]) into b using (r->>teile[3])::uuid;
    else b := (r->>q)::uuid; end if;
  end if;
  insert into public.verlauf (bereich, bezug_id, tabelle, datensatz_id, aktion, alt, neu, rueck)
  values (tg_argv[0], b, tg_table_name, (r->>'id')::uuid, left(tg_op, 1),
    case when tg_op <> 'INSERT' then to_jsonb(old) end, case when tg_op <> 'DELETE' then to_jsonb(new) end,
    coalesce(current_setting('kg.rueck', true), '') = '1');
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array['planer_einsatz','planer_ressource_einsatz','planer_einsatz_info','planer_vorrat','planer_vorschlag_notiz','planer_markierung','planer_magazin','planer_pendenz','planer_ferien'] loop
    execute format('drop trigger if exists verlauf on public.%I', t);
    execute format('create trigger verlauf after insert or update or delete on public.%I for each row execute function verlauf_schreiben(%L)', t, 'planer');
  end loop;
  execute 'drop trigger if exists verlauf on public.offerte';
  execute 'create trigger verlauf after insert or update or delete on public.offerte for each row execute function verlauf_schreiben(''offerte'', ''id'')';
  foreach t in array array['offerte_arbeitsschritt_option','offerte_arbeitsschritt_tage','offerte_artikel_position','offerte_auswahl','offerte_eigene_position','offerte_eigene_zeile','offerte_eigener_teilschritt','offerte_eingabefeld_notiz','offerte_eingabefeld_wert','offerte_geometrie_element','offerte_ressourcenzeile_korrektur','offerte_tabelle_zeile','offerte_teilschritt_option','offerte_teilschritt_tage','offerte_teilschritt_zeile','offerte_zeilen_korrektur'] loop
    execute format('drop trigger if exists verlauf on public.%I', t);
    execute format('create trigger verlauf after insert or update or delete on public.%I for each row execute function verlauf_schreiben(%L, %L)', t, 'offerte', 'offerte_id');
  end loop;
  execute 'drop trigger if exists verlauf on public.offerte_eigene_position_material';
  execute 'create trigger verlauf after insert or update or delete on public.offerte_eigene_position_material for each row execute function verlauf_schreiben(''offerte'', ''eltern:offerte_eigene_position:eigene_position_id'')';
  execute 'drop trigger if exists verlauf on public.offerte_eigene_teilschritt_zeile';
  execute 'create trigger verlauf after insert or update or delete on public.offerte_eigene_teilschritt_zeile for each row execute function verlauf_schreiben(''offerte'', ''eltern:offerte_eigener_teilschritt:eigener_teilschritt_id'')';
  execute 'drop trigger if exists verlauf on public.offerte_tabelle_wert';
  execute 'create trigger verlauf after insert or update or delete on public.offerte_tabelle_wert for each row execute function verlauf_schreiben(''offerte'', ''eltern:offerte_tabelle_zeile:zeile_id'')';
end $$;

-- Anwenden: richtung 'zurueck' setzt den Stand vor den Einträgen (ids in der gewünschten Reihenfolge, neueste zuerst),
-- 'vor' wendet sie wieder an (älteste zuerst). Ohne erzwingen: zuerst prüfen, ob seither jemand denselben Datensatz geändert hat.
-- Läuft mit den Rechten des Benutzers (RLS gilt). Fremdschlüssel-Reihenfolge: bis zu 6 Durchgänge.
create or replace function public.verlauf_anwenden(ids bigint[], richtung text, erzwingen boolean default false)
returns jsonb language plpgsql security invoker set search_path to 'public' as $$
declare v record; soll jsonb; ist jsonb; ziel jsonb; quelle jsonb; k text; ks text[]; konf jsonb := '[]'; offen bigint[] := ids; rest bigint[]; n int := 0; cols text; fehler text;
begin
  perform set_config('kg.rueck', '1', true);
  -- 1) Prüfen
  if not erzwingen then
    for v in select * from verlauf where id = any(ids) loop
      execute format('select to_jsonb(t) from public.%I t where id = $1', v.tabelle) into ist using v.datensatz_id;
      soll := case when richtung = 'zurueck' then v.neu else v.alt end; -- so sollte der Datensatz jetzt aussehen
      if soll is null then
        if ist is not null then konf := konf || jsonb_build_object('id', v.id); end if;
      elsif ist is null then konf := konf || jsonb_build_object('id', v.id);
      elsif v.alt is null or v.neu is null then -- neu angelegt: seither verändert?
        for k in select key from jsonb_each(soll) where key not like '%\_am' and key <> 'updated_at' loop
          if (ist->k) is distinct from (soll->k) then konf := konf || jsonb_build_object('id', v.id); exit; end if;
        end loop;
      else
        for k in select key from jsonb_each(coalesce(v.neu, '{}')) where v.alt is not null and v.neu is not null and (v.alt->key) is distinct from (v.neu->key) loop
          if (ist->k) is distinct from (soll->k) then konf := konf || jsonb_build_object('id', v.id); exit; end if;
        end loop;
      end if;
    end loop;
    if jsonb_array_length(konf) > 0 then return jsonb_build_object('ok', false, 'konflikte', konf); end if;
  end if;
  -- 2) Anwenden
  while array_length(offen, 1) > 0 and n < 6 loop
    n := n + 1; rest := '{}';
    for v in select x.* from unnest(offen) with ordinality u(vid, ord) join verlauf x on x.id = u.vid order by u.ord loop
      begin
        ziel := case when richtung = 'zurueck' then v.alt else v.neu end;
        quelle := case when richtung = 'zurueck' then v.neu else v.alt end;
        select string_agg(quote_ident(column_name), ',' order by ordinal_position) into cols from information_schema.columns
          where table_schema = 'public' and table_name = v.tabelle and is_generated = 'NEVER';
        if ziel is null then
          execute format('delete from public.%I where id = $1', v.tabelle) using v.datensatz_id;
        elsif quelle is null then
          execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I, $1) on conflict (id) do nothing', v.tabelle, cols, cols, v.tabelle) using ziel;
        else
          select array_agg(quote_ident(key)) into ks from jsonb_each(ziel) e
            where (ziel->key) is distinct from (quelle->key)
              and exists (select 1 from information_schema.columns c where c.table_schema = 'public' and c.table_name = v.tabelle and c.column_name = e.key and c.is_generated = 'NEVER');
          if ks is not null then
            if array_length(ks, 1) = 1 then
              execute format('update public.%I set %s = (select r.%s from jsonb_populate_record(null::public.%I, $1) r) where id = $2', v.tabelle, ks[1], ks[1], v.tabelle) using ziel, v.datensatz_id;
            else
              execute format('update public.%I set (%s) = (select %s from jsonb_populate_record(null::public.%I, $1) r) where id = $2', v.tabelle,
                array_to_string(ks, ','), (select string_agg('r.' || x, ',') from unnest(ks) x), v.tabelle) using ziel, v.datensatz_id;
            end if;
          end if;
        end if;
      exception when others then rest := rest || v.id; fehler := sqlerrm;
      end;
    end loop;
    offen := rest;
  end loop;
  if array_length(offen, 1) > 0 then return jsonb_build_object('ok', false, 'fehler', fehler, 'offen', to_jsonb(offen)); end if;
  return jsonb_build_object('ok', true);
end $$;
grant execute on function public.verlauf_anwenden(bigint[], text, boolean) to authenticated;

-- Aufräumen: täglich 03:15 alles älter als 90 Tage
select cron.unschedule('verlauf_aufraeumen') where exists (select 1 from cron.job where jobname = 'verlauf_aufraeumen');
select cron.schedule('verlauf_aufraeumen', '15 3 * * *', $$delete from public.verlauf where zeit < now() - interval '90 days'$$);
