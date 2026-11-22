-- Tool-Menü neu: «Meine Tools» (an = true, gross, Reihenfolge per Ziehen) und «Weitere Tools» (an = false, klein).
-- Häufigkeit pro Person: aufrufe zählt das Öffnen eines Tools (höchstens einmal pro 20 Minuten).
-- Ohne Zeile: Tool bei «Meine Tools», ausser Einstellungen (verw) bei «Weitere Tools».
-- Schalter «nach Häufigkeit» bei «Weitere Tools»: Zeile app_key '_weitere_haeufig', an = Schalter (ohne Zeile = an).
alter table public.tool_menue add column if not exists aufrufe integer not null default 0;
alter table public.tool_menue add column if not exists zuletzt timestamptz;

create or replace function public.tool_aufruf(p_key text)
returns void language sql security invoker set search_path = public as $$
  insert into tool_menue (benutzer_id, app_key, sortierung, an, aufrufe, zuletzt)
  values (auth.uid(), p_key, 1000, p_key <> 'verw', 1, now())   -- neue Zeile wie ohne Zeile: alle bei «Meine Tools», Einstellungen bei «Weitere»
  on conflict (benutzer_id, app_key) do update
    set aufrufe = tool_menue.aufrufe + case when tool_menue.zuletzt is null or tool_menue.zuletzt < now() - interval '20 minutes' then 1 else 0 end,
        zuletzt = now();
$$;
grant execute on function public.tool_aufruf(text) to authenticated;

select string_agg(column_name, ',') as spalten from information_schema.columns where table_name = 'tool_menue';
