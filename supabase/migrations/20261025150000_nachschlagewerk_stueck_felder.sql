-- Nachschlagewerk: feste Felder pro Stück (Baustein «Mehrfach»).
-- Alte Angaben werden auf die festen Bezeichnungen umgeschrieben, alles Übrige kommt als Zeile in die Notiz des Stücks.
-- Sicherung der alten Angaben in wissen_exemplar_steckbrief_alt.

create table if not exists public.wissen_exemplar_steckbrief_alt (
  id uuid primary key, steckbrief jsonb not null, gesichert_am timestamptz not null default now());
alter table public.wissen_exemplar_steckbrief_alt enable row level security;
insert into public.wissen_exemplar_steckbrief_alt (id, steckbrief)
  select id, steckbrief from public.wissen_exemplar where jsonb_array_length(steckbrief) > 0
  on conflict (id) do nothing;

create or replace function pg_temp.sw(sb jsonb, l text) returns text language sql as $f$
  select nullif(trim(r->>'wert'), '') from jsonb_array_elements(coalesce(sb, '[]'::jsonb)) r where r->>'label' = l limit 1 $f$;

do $$
declare
  x record; r jsonb; neu jsonb; rest text; v text; l text; i int; n record; benutzt text[];
  marke text[] := array['Marke / Modell', 'Hersteller / Modell', 'Hersteller'];
  jahr text[] := array['Anschaffungsjahr', 'Baujahr'];
  st_l text[] := array['km Januar 2026', 'Betriebsstunden Nov. 2025', 'Betriebsstunden Okt. 2025', 'km Januar 2025', 'Betriebsstunden Nov. 2024', 'Betriebsstunden'];
  st_p text[] := array['2026-01', '2025-11', '2025-10', '2025-01', '2024-11', null];
begin
  for x in select * from public.wissen_exemplar where jsonb_array_length(steckbrief) > 0 loop
    neu := '[]'::jsonb; rest := ''; benutzt := '{}';
    -- Kontrollschild = Nummer (sonst Nummer setzen bzw. in die Notiz)
    v := pg_temp.sw(x.steckbrief, 'Kontrollschild');
    if v is not null then
      benutzt := benutzt || 'Kontrollschild'::text;
      if x.nummer is null then update public.wissen_exemplar set nummer = v where id = x.id;
      elsif x.nummer <> v then rest := rest || 'Kontrollschild: ' || v || E'\n'; end if;
    end if;
    -- Marke / Modell und Anschaffungsjahr: erste vorhandene Bezeichnung
    foreach l in array marke loop v := pg_temp.sw(x.steckbrief, l);
      if v is not null then neu := neu || jsonb_build_object('label', 'Marke / Modell', 'wert', v); benutzt := benutzt || l; exit; end if; end loop;
    foreach l in array jahr loop v := pg_temp.sw(x.steckbrief, l);
      if v is not null then neu := neu || jsonb_build_object('label', 'Anschaffungsjahr', 'wert', v); benutzt := benutzt || l; exit; end if; end loop;
    -- Stand: neuster Zählerstand, mit Einheit und Monat
    for i in 1 .. array_length(st_l, 1) loop v := pg_temp.sw(x.steckbrief, st_l[i]);
      if v is not null then
        neu := neu || jsonb_build_object('label', 'Stand', 'wert', case when v ~ '\s(h|km)$' then v when st_l[i] like 'km%' then v || ' km' else v || ' h' end);
        if st_p[i] is not null then neu := neu || jsonb_build_object('label', 'Stand per', 'wert', st_p[i]); end if;
        benutzt := benutzt || st_l[i]; exit;
      end if; end loop;
    -- Versicherung aus Kaskoschutz
    v := pg_temp.sw(x.steckbrief, 'Kaskoschutz');
    if v is not null then benutzt := benutzt || 'Kaskoschutz'::text;
      neu := neu || jsonb_build_object('label', 'Versicherung', 'wert', case lower(v) when 'keine' then 'Keine' when 'teil' then 'Teilkasko' when 'voll' then 'Vollkasko' else v end); end if;
    v := pg_temp.sw(x.steckbrief, 'Selbstbehalt');
    if v is not null then benutzt := benutzt || 'Selbstbehalt'::text; neu := neu || jsonb_build_object('label', 'Selbstbehalt', 'wert', regexp_replace(v, '^CHF\s*', '')); end if;
    v := pg_temp.sw(x.steckbrief, 'Fahrzeugprüfung');
    if v is not null then benutzt := benutzt || 'Fahrzeugprüfung'::text; neu := neu || jsonb_build_object('label', 'Nächste Prüfung', 'wert', v); end if;
    v := pg_temp.sw(x.steckbrief, 'Seriennummer');
    if v is not null then benutzt := benutzt || 'Seriennummer'::text; neu := neu || jsonb_build_object('label', 'Seriennummer', 'wert', v); end if;
    v := pg_temp.sw(x.steckbrief, 'Kaufpreis');
    if v is not null then benutzt := benutzt || 'Kaufpreis'::text; neu := neu || jsonb_build_object('label', 'Kaufpreis', 'wert', regexp_replace(v, '^CHF\s*', '')); end if;
    -- alles Übrige als Zeile in die Notiz
    for r in select * from jsonb_array_elements(x.steckbrief) loop
      if nullif(trim(r->>'wert'), '') is not null and not ((r->>'label') = any(benutzt)) then
        rest := rest || coalesce(nullif(r->>'label', '') || ': ', '') || trim(r->>'wert') || E'\n'; end if;
    end loop;
    update public.wissen_exemplar set steckbrief = neu where id = x.id;
    rest := trim(trailing E'\n' from rest);
    if rest <> '' then
      select * into n from public.wissen_notiz where eintrag_id = x.eintrag_id and exemplar_id = x.id limit 1;
      rest := replace(replace(replace(rest, '&', '&amp;'), '<', '&lt;'), E'\n', '<br>');
      if found then update public.wissen_notiz set html = case when trim(html) = '' then rest else html || '<br>' || rest end where id = n.id;
      else insert into public.wissen_notiz (eintrag_id, exemplar_id, html) values (x.eintrag_id, x.id, rest); end if;
    end if;
  end loop;
end $$;
