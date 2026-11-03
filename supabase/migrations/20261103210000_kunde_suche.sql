-- Kundensuche in der lokalen Tabelle kunde (seit dem nächtlichen Easybill-Abgleich vollständig).
-- Für Doku-Tools (Adresse übernehmen) und die Seite Kontakte. Liest mit den Rechten des Aufrufers (RLS kunde_lesen).
create or replace function public.kunde_suche(q text, anzahl int default 20)
returns table(id uuid, name text, strasse text, plz text, ort text, kundennummer text, easybill_id bigint)
language sql stable security invoker set search_path = public as $$
  with w as (select unnest(regexp_split_to_array(lower(trim(coalesce(q, ''))), '\s+')) as wort)
  select k.id,
         coalesce(nullif(trim(k.firma), ''), nullif(trim(concat_ws(' ', k.vorname, k.nachname)), ''), k.name) as name,
         k.strasse, k.plz::text, k.ort, k.kundennummer::text, k.easybill_id::bigint
  from kunde k
  where length(trim(coalesce(q, ''))) >= 2
    and not exists (select 1 from w where wort <> '' and lower(concat_ws(' ', k.name, k.firma, k.vorname, k.nachname, k.strasse, k.plz, k.ort, k.kundennummer)) not like '%' || wort || '%')
  order by (lower(coalesce(nullif(trim(k.firma), ''), k.nachname, k.name)) like lower(trim(q)) || '%') desc, 2
  limit greatest(1, least(coalesce(anzahl, 20), 100));
$$;
grant execute on function public.kunde_suche(text, int) to authenticated;
revoke execute on function public.kunde_suche(text, int) from anon, public;
