-- Offertensuche «Überall suchen» (Stefan, 17.11.2026): ein Suchtext pro Offerte, rechnet die Datenbank selbst nach jedem Speichern
-- Inhalt: Titel, Offertnummer, alle Positionen im Blatt (kosten_snapshot), Arbeitsbeschrieb, Optionen-Text, Notiz, «noch offen»
alter table public.offerte drop column if exists suchtext;
alter table public.offerte add column suchtext text generated always as (lower(
  coalesce(titel, '') || ' ' || coalesce(offertnummer, '') || ' ' ||
  coalesce(jsonb_path_query_array(kosten_snapshot, '$.gruppen[*].zeilen[*].bezeichnung')::text, '') || ' ' ||
  coalesce(beschreibung_block, '') || ' ' || coalesce(optionen_text_liste, '') || ' ' ||
  coalesce(notiz, '') || ' ' || coalesce(noch_offen, '')
)) stored;
create extension if not exists pg_trgm;
create index if not exists offerte_suchtext_trgm on public.offerte using gin (suchtext gin_trgm_ops);
select count(*) filter (where suchtext like '%skimmer%') skimmer, count(*) alle from public.offerte;
