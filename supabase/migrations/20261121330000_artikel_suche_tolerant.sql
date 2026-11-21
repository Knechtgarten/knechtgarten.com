-- Fehlertolerante Artikelsuche (Stefan 2026-11-21): «Koi-Brieder» findet Koi-Breeder, «koi breeder» = «Koi-Breeder»
-- such_kompakt = Bezeichnung + Nummern + Anmerkung + Lieferant, klein, Umlaute ausgeschrieben, ohne Leer-/Sonderzeichen.
-- Artikelstamm (Tool C) sucht pro Wort zusätzlich in such_kompakt; bei 0 Treffern liefert artikel_suche_unscharf() ähnliche Artikel (pg_trgm).

create or replace function public.kg_such_kompakt(t text) returns text
language sql immutable as $$
  select regexp_replace(replace(replace(replace(replace(lower(coalesce(t, '')), 'ä', 'ae'), 'ö', 'oe'), 'ü', 'ue'), 'ß', 'ss'), '[^a-z0-9]', '', 'g')
$$;

alter table artikel add column if not exists such_kompakt text;

create or replace function public.artikel_such_kompakt_setzen() returns trigger
language plpgsql as $$
begin
  new.such_kompakt := public.kg_such_kompakt(concat_ws(' ', new.bezeichnung, new.artikelnummer_knecht, new.artikelnummer_lieferant, new.anmerkung,
    (select l.name from lieferant l where l.id = new.lieferant_id)));
  return new;
end $$;

drop trigger if exists artikel_such_kompakt on artikel;
create trigger artikel_such_kompakt before insert or update of bezeichnung, artikelnummer_knecht, artikelnummer_lieferant, anmerkung, lieferant_id
  on artikel for each row execute function public.artikel_such_kompakt_setzen();

-- Lieferant umbenannt → Suchtext seiner Artikel nachführen
create or replace function public.lieferant_name_such_kompakt() returns trigger
language plpgsql as $$
begin
  if new.name is distinct from old.name then
    update artikel set such_kompakt = public.kg_such_kompakt(concat_ws(' ', bezeichnung, artikelnummer_knecht, artikelnummer_lieferant, anmerkung, new.name))
    where lieferant_id = new.id;
  end if;
  return new;
end $$;
drop trigger if exists lieferant_name_such_kompakt on lieferant;
create trigger lieferant_name_such_kompakt after update of name on lieferant for each row execute function public.lieferant_name_such_kompakt();

-- bestehende Artikel füllen (ohne die übrigen Trigger wie VP-Automatik auszulösen: nur such_kompakt ändert sich)
update artikel a set such_kompakt = public.kg_such_kompakt(concat_ws(' ', a.bezeichnung, a.artikelnummer_knecht, a.artikelnummer_lieferant, a.anmerkung, l.name))
from lieferant l where l.id = a.lieferant_id and a.such_kompakt is distinct from public.kg_such_kompakt(concat_ws(' ', a.bezeichnung, a.artikelnummer_knecht, a.artikelnummer_lieferant, a.anmerkung, l.name));

create index if not exists artikel_such_kompakt_trgm on artikel using gin (such_kompakt gin_trgm_ops);

-- Ähnliche Artikel: jedes Wort muss «ungefähr» vorkommen (word_similarity ≥ 0.45), sortiert nach Ähnlichkeit
create or replace function public.artikel_suche_unscharf(q text, anzahl int default 200)
returns setof uuid language sql stable as $$
  with w as (select public.kg_such_kompakt(x) w from regexp_split_to_table(coalesce(q, ''), '\s+') x where public.kg_such_kompakt(x) <> '')
  select a.id from artikel a
  where exists (select 1 from w) and not exists (select 1 from w where a.such_kompakt not like '%' || w.w || '%' and word_similarity(w.w, a.such_kompakt) < 0.45)
  order by (select sum(word_similarity(w.w, a.such_kompakt)) from w) desc
  limit anzahl
$$;
grant execute on function public.artikel_suche_unscharf(text, int) to authenticated;
grant execute on function public.kg_such_kompakt(text) to authenticated;

select count(*) filter (where such_kompakt is not null) gefuellt, count(*) total,
  (select count(*) from public.artikel_suche_unscharf('Koi-Brieder')) koi_brieder,
  (select string_agg(a.bezeichnung, ' | ') from (select bezeichnung from artikel where id in (select public.artikel_suche_unscharf('baddu alpha', 3))) a) badu
from artikel;

-- Nachtrag: Trigramme allein sind für Tippfehler in zusammengeschriebenem Text zu grob («koibrieder» nur 0.43).
-- Gleiche Regel wie in Tool A/B (KG.suchPasst): pro Wort ab 5 Zeichen 1, ab 8 Zeichen 2 Tippfehler (Levenshtein über Textausschnitte).
create extension if not exists fuzzystrmatch with schema extensions;

create or replace function public.kg_wort_unscharf(t text, w text) returns boolean
language plpgsql immutable as $$
declare mx int; l int; i int;
begin
  if t is null or w is null or w = '' then return false; end if;
  if position(w in t) > 0 then return true; end if;
  mx := case when length(w) >= 8 then 2 when length(w) >= 5 then 1 else 0 end;
  if mx = 0 then return false; end if;
  for l in greatest(2, length(w) - mx) .. length(w) + mx loop
    for i in 1 .. greatest(0, length(t) - l + 1) loop
      if extensions.levenshtein_less_equal(w, substr(t, i, l), mx) <= mx then return true; end if;
    end loop;
  end loop;
  return false;
end $$;

create or replace function public.artikel_suche_unscharf(q text, anzahl int default 200)
returns setof uuid language sql stable as $$
  with w as (select public.kg_such_kompakt(x) w from regexp_split_to_table(coalesce(q, ''), '\s+') x where public.kg_such_kompakt(x) <> '')
  select a.id from artikel a
  where exists (select 1 from w) and not exists (select 1 from w where not public.kg_wort_unscharf(a.such_kompakt, w.w))
  order by (select sum(word_similarity(w.w, a.such_kompakt)) from w) desc
  limit anzahl
$$;

select (select count(*) from public.artikel_suche_unscharf('Koi-Brieder')) koi_brieder,
  (select string_agg(a.bezeichnung, ' | ') from (select bezeichnung from artikel where id in (select public.artikel_suche_unscharf('baddu alpha', 3))) a) badu;
