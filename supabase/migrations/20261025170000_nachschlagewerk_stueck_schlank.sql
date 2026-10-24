-- Nachschlagewerk: Stück schlanker.
-- 1) «Stand» / «Stand per» werden eine Zeile «Stand» beim Service (wissen_service_erledigt ohne Service-Arbeit).
-- 2) «Selbstbehalt», «Nächste Prüfung», «Kaufpreis» kommen als Zeile in die Notiz des Stücks.
-- 3) Planer-Namen nach Regel: Fahrzeug = Vorname des Fahrers, sonst Marke / Modell, Ersatz Titel; Nummer vom Stück.
-- Sicherung: aktuelle Angaben in wissen_exemplar_steckbrief_alt2.

create table if not exists public.wissen_exemplar_steckbrief_alt2 (
  id uuid primary key, steckbrief jsonb not null, gesichert_am timestamptz not null default now());
alter table public.wissen_exemplar_steckbrief_alt2 enable row level security;
insert into public.wissen_exemplar_steckbrief_alt2 (id, steckbrief)
  select id, steckbrief from public.wissen_exemplar where jsonb_array_length(steckbrief) > 0 on conflict (id) do nothing;

create or replace function pg_temp.sw(sb jsonb, l text) returns text language sql as $f$
  select nullif(trim(r->>'wert'), '') from jsonb_array_elements(coalesce(sb, '[]'::jsonb)) r where r->>'label' = l limit 1 $f$;

do $$
declare x record; v text; per text; d date; rest text; n record;
begin
  for x in select * from public.wissen_exemplar where jsonb_array_length(steckbrief) > 0 loop
    -- 1) Stand
    v := pg_temp.sw(x.steckbrief, 'Stand'); per := pg_temp.sw(x.steckbrief, 'Stand per');
    if v is not null then
      d := case when per ~ '^\d{4}-\d{2}$' then (per || '-01')::date else null end;
      insert into public.wissen_service_erledigt (eintrag_id, exemplar_id, service_id, arbeit, jahr, kw, erledigt, datum, stand)
        values (x.eintrag_id, x.id, null, 'Stand', coalesce(extract(isoyear from d)::int, extract(year from now())::int),
                coalesce(extract(week from d)::int, 1), true, d, v);
    end if;
    -- 2) gestrichene Felder in die Notiz
    rest := concat_ws(E'\n',
      case when pg_temp.sw(x.steckbrief, 'Selbstbehalt') is not null then 'Selbstbehalt: CHF ' || pg_temp.sw(x.steckbrief, 'Selbstbehalt') end,
      case when pg_temp.sw(x.steckbrief, 'Nächste Prüfung') is not null then 'Nächste Prüfung: ' || pg_temp.sw(x.steckbrief, 'Nächste Prüfung') end,
      case when pg_temp.sw(x.steckbrief, 'Kaufpreis') is not null then 'Kaufpreis: CHF ' || pg_temp.sw(x.steckbrief, 'Kaufpreis') end);
    if rest <> '' then
      rest := replace(replace(replace(rest, '&', '&amp;'), '<', '&lt;'), E'\n', '<br>');
      select * into n from public.wissen_notiz where eintrag_id = x.eintrag_id and exemplar_id = x.id limit 1;
      if found then update public.wissen_notiz set html = case when trim(html) = '' then rest else html || '<br>' || rest end where id = n.id;
      else insert into public.wissen_notiz (eintrag_id, exemplar_id, html) values (x.eintrag_id, x.id, rest); end if;
    end if;
    update public.wissen_exemplar set steckbrief = (select coalesce(jsonb_agg(r), '[]'::jsonb) from jsonb_array_elements(x.steckbrief) r
      where r->>'label' not in ('Stand', 'Stand per', 'Selbstbehalt', 'Nächste Prüfung', 'Kaufpreis')) where id = x.id;
  end loop;
end $$;

-- 3) Planer-Namen
update public.planer_ressource r set
  nummer = x.nummer,
  name = coalesce(case when r.typ = 'fahrzeug' then nullif(split_part(coalesce(x.zustaendig, ''), ' ', 1), '') end, pg_temp.sw(x.steckbrief, 'Marke / Modell'), e.titel)
from public.wissen_exemplar x join public.wissen_eintrag e on e.id = x.eintrag_id
where x.planer_ressource_id = r.id and x.archiviert_am is null;
