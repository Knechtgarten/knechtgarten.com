-- Adressänderung, Objekte, inaktive Kunden, Verknüpfungen (Entscheid Stefan 2026-11-19)
--
-- Etappe 1  offerte.adresse_fix: eingefrorene Adresse einer Offerte (null = folgt dem Kunden).
--           Funktion kunde_adresse_aendern: Kunde ändern + bestimmen, welche Offerten die neue Adresse bekommen.
--           kunde_adresse_verlauf: jede Änderung (Tool oder Easybill-Nachtabgleich).
-- Etappe 2  kunde_objekt: weitere Adressen eines Kunden (Liegenschaft, Ferienhaus, bisherige Adresse nach Umzug).
--           offerte.objekt_id: Arbeitsort der Offerte (null = Kundenadresse).
-- Etappe 3  kunde.inaktiv, kunde_beziehung (gleiche Person, Vorbesitzer/Nachfolger, Verwaltung …).
-- Lieferanschrift (nur 2 Kunden) wird zu Objekten.

-- Schreibrecht wie bei der Tabelle kunde
create or replace function kunde_darf_bearbeiten() returns boolean language sql stable security definer set search_path = public as $$
  select recht_wert('offerten', 'kunden', 'bearbeiten') <> 'K' or recht_wert('pflege', 'kunden', 'bearbeiten') <> 'K'
$$;

-- ---------------------------------------------------------------- Kunde inaktiv
alter table kunde add column if not exists inaktiv boolean not null default false,
                  add column if not exists inaktiv_seit date;

-- ---------------------------------------------------------------- Objekte
create table if not exists kunde_objekt (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete cascade,
  name text,                       -- Bezeichnung, z. B. «Ferienhaus», «Bisherige Adresse»
  strasse text, plz text, ort text, land text,
  notiz text,
  inaktiv boolean not null default false,
  reihenfolge integer not null default 0,
  erstellt_am timestamptz not null default now(),
  erstellt_von uuid default auth.uid()
);
create index if not exists kunde_objekt_kunde on kunde_objekt(kunde_id);
alter table kunde_objekt enable row level security;
drop policy if exists kunde_objekt_lesen on kunde_objekt;
create policy kunde_objekt_lesen on kunde_objekt for select using (ist_eingeloggter_benutzer());
drop policy if exists kunde_objekt_schreiben on kunde_objekt;
create policy kunde_objekt_schreiben on kunde_objekt for all using (kunde_darf_bearbeiten()) with check (kunde_darf_bearbeiten());

-- Offerte: Arbeitsort und eingefrorene Adresse
alter table offerte add column if not exists objekt_id uuid references kunde_objekt(id) on delete restrict,
                    add column if not exists adresse_fix jsonb;
create index if not exists offerte_objekt on offerte(objekt_id) where objekt_id is not null;

-- Objekt mit Offerten darf nicht gelöscht werden (restrict oben); Kunde mit Objekt-Offerten ist über offerte schon geschützt.

-- Lieferanschriften übernehmen (nur wo etwas drinsteht)
insert into kunde_objekt (kunde_id, name, strasse, plz, ort, land, erstellt_von)
select id, 'Lieferadresse', nullif(lieferanschrift->>'strasse', ''), nullif(lieferanschrift->>'plz', ''), nullif(lieferanschrift->>'ort', ''), nullif(lieferanschrift->>'land', ''), null
from kunde
where coalesce(nullif(lieferanschrift->>'strasse', ''), nullif(lieferanschrift->>'plz', ''), nullif(lieferanschrift->>'ort', '')) is not null
  and not exists (select 1 from kunde_objekt o where o.kunde_id = kunde.id and o.name = 'Lieferadresse');

-- ---------------------------------------------------------------- Verknüpfungen
-- art: gleich (gleiche Person/Inhaber), nachfolger (von = Vorbesitzer, zu = Nachfolger),
--      verwaltung (von verwaltet zu), mieter (von ist Mieter bei zu), architekt (von ist Architekt/Planer für zu), andere
create table if not exists kunde_beziehung (
  id uuid primary key default gen_random_uuid(),
  kunde_von uuid not null references kunde(id) on delete cascade,
  kunde_zu uuid not null references kunde(id) on delete cascade,
  art text not null check (art in ('gleich', 'nachfolger', 'verwaltung', 'mieter', 'architekt', 'andere')),
  notiz text,
  erstellt_am timestamptz not null default now(),
  erstellt_von uuid default auth.uid(),
  check (kunde_von <> kunde_zu),
  unique (kunde_von, kunde_zu, art)
);
create index if not exists kunde_beziehung_zu on kunde_beziehung(kunde_zu);
alter table kunde_beziehung enable row level security;
drop policy if exists kunde_beziehung_lesen on kunde_beziehung;
create policy kunde_beziehung_lesen on kunde_beziehung for select using (ist_eingeloggter_benutzer());
drop policy if exists kunde_beziehung_schreiben on kunde_beziehung;
create policy kunde_beziehung_schreiben on kunde_beziehung for all using (kunde_darf_bearbeiten()) with check (kunde_darf_bearbeiten());

-- ---------------------------------------------------------------- Verlauf
create table if not exists kunde_adresse_verlauf (
  id uuid primary key default gen_random_uuid(),
  kunde_id uuid not null references kunde(id) on delete cascade,
  alt jsonb, neu jsonb,
  art text,                        -- korrektur | umzug_objekt | umzug_weg | name | easybill
  quelle text not null default 'tool' check (quelle in ('tool', 'easybill')),
  objekt_id uuid references kunde_objekt(id) on delete set null,
  von uuid default auth.uid(),
  am timestamptz not null default now()
);
create index if not exists kunde_adresse_verlauf_kunde on kunde_adresse_verlauf(kunde_id, am desc);
alter table kunde_adresse_verlauf enable row level security;
drop policy if exists kunde_adresse_verlauf_lesen on kunde_adresse_verlauf;
create policy kunde_adresse_verlauf_lesen on kunde_adresse_verlauf for select using (ist_eingeloggter_benutzer());

-- Adress-Kopie eines Kunden (für adresse_fix und Verlauf)
create or replace function kunde_adresse_json(k kunde) returns jsonb language sql immutable as $$
  select jsonb_build_object('name', k.name, 'firma', k.firma, 'anrede', k.anrede, 'vorname', k.vorname, 'nachname', k.nachname,
    'zusatz1', k.zusatz1, 'zusatz2', k.zusatz2, 'strasse', k.strasse, 'plz', k.plz, 'ort', k.ort, 'land', k.land)
$$;

-- ---------------------------------------------------------------- Kunde ändern (aus Kontakte und Offertentool)
-- p_neu      alle Felder des Kunden (wie das Bearbeiten-Fenster sie hat)
-- p_art      null (nichts Wesentliches geändert) | korrektur | umzug_objekt | umzug_weg | name
-- p_offerten Offerten, die die neue Adresse bekommen; alle anderen behalten die bisherige (eingefroren)
-- Rückgabe   { objekt_id, eingefroren, neu }
create or replace function kunde_adresse_aendern(p_kunde uuid, p_neu jsonb, p_art text default null, p_offerten uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  k kunde; alt jsonb; obj uuid; n_fix int := 0; n_neu int := 0;
  adr_neu boolean;
  t text := nullif(p_art, '');
begin
  if not kunde_darf_bearbeiten() then raise exception 'Keine Berechtigung, Kunden zu bearbeiten.'; end if;
  select * into k from kunde where id = p_kunde for update;
  if k.id is null then raise exception 'Kunde nicht gefunden.'; end if;
  alt := kunde_adresse_json(k);
  p_offerten := coalesce(p_offerten, '{}');
  adr_neu := coalesce(p_neu->>'strasse', '') is distinct from coalesce(k.strasse, '')
          or coalesce(p_neu->>'plz', '') is distinct from coalesce(k.plz, '')
          or coalesce(p_neu->>'ort', '') is distinct from coalesce(k.ort, '');

  if t = 'umzug_objekt' then
    -- bisherige Adresse wird Objekt, Offerten ohne Häkchen gehören ab jetzt zu diesem Objekt
    insert into kunde_objekt (kunde_id, name, strasse, plz, ort, land)
    values (p_kunde, 'Bisherige Adresse', k.strasse, k.plz, k.ort, k.land) returning id into obj;
    update offerte set objekt_id = obj
     where kunde_id = p_kunde and objekt_id is null and adresse_fix is null and not (id = any(p_offerten));
    get diagnostics n_fix = row_count;
  elsif t is not null then
    -- Offerten ohne Häkchen behalten die bisherige Adresse (Kopie)
    update offerte set adresse_fix = alt
     where kunde_id = p_kunde and objekt_id is null and adresse_fix is null and not (id = any(p_offerten));
    get diagnostics n_fix = row_count;
  end if;
  -- Offerten mit Häkchen folgen dem Kunden (auch früher eingefrorene)
  if t is not null then
    update offerte set adresse_fix = null where kunde_id = p_kunde and id = any(p_offerten) and adresse_fix is not null;
    get diagnostics n_neu = row_count;
  end if;

  update kunde set
    name = coalesce(nullif(p_neu->>'name', ''), name),
    kundennummer = case when p_neu ? 'kundennummer' then nullif(p_neu->>'kundennummer', '') else kundennummer end,
    firma = case when p_neu ? 'firma' then nullif(p_neu->>'firma', '') else firma end,
    anrede = case when p_neu ? 'anrede' then nullif(p_neu->>'anrede', '') else anrede end,
    vorname = case when p_neu ? 'vorname' then nullif(p_neu->>'vorname', '') else vorname end,
    nachname = case when p_neu ? 'nachname' then nullif(p_neu->>'nachname', '') else nachname end,
    zusatz1 = case when p_neu ? 'zusatz1' then nullif(p_neu->>'zusatz1', '') else zusatz1 end,
    zusatz2 = case when p_neu ? 'zusatz2' then nullif(p_neu->>'zusatz2', '') else zusatz2 end,
    strasse = case when p_neu ? 'strasse' then nullif(p_neu->>'strasse', '') else strasse end,
    plz = case when p_neu ? 'plz' then nullif(p_neu->>'plz', '') else plz end,
    ort = case when p_neu ? 'ort' then nullif(p_neu->>'ort', '') else ort end,
    land = case when p_neu ? 'land' then nullif(p_neu->>'land', '') else land end,
    kontaktdaten = case when p_neu ? 'kontaktdaten' then p_neu->'kontaktdaten' else kontaktdaten end,
    geo_lat = case when adr_neu then null else geo_lat end,
    geo_lon = case when adr_neu then null else geo_lon end,
    geo_stand = case when adr_neu then null else geo_stand end
  where id = p_kunde
  returning * into k;

  if t is not null then
    insert into kunde_adresse_verlauf (kunde_id, alt, neu, art, quelle, objekt_id) values (p_kunde, alt, kunde_adresse_json(k), t, 'tool', obj);
  end if;
  return jsonb_build_object('objekt_id', obj, 'eingefroren', n_fix, 'neu', n_neu);
end $$;
grant execute on function kunde_adresse_aendern(uuid, jsonb, text, uuid[]) to authenticated;

-- ---------------------------------------------------------------- Nachtabgleich Easybill
-- Ändert Easybill nachts Name oder Adresse: abgeschlossene Offerten (bestätigt, zugesagt, abgelehnt) behalten die
-- bisherige Adresse, offene folgen. Verlauf + Hinweis-Pendenz in der App-Box der Person, die die offene Offerte erstellt hat
-- (sonst beim Administrator). Nur wenn niemand angemeldet ist (= Abgleich mit Service-Schlüssel).
create or replace function kunde_easybill_aenderung() returns trigger language plpgsql security definer set search_path = public as $$
declare
  alt jsonb := kunde_adresse_json(old); n_fix int; n_offen int; wer uuid; box uuid; was text;
begin
  if auth.uid() is not null then return new; end if;
  if coalesce(old.strasse, '') = coalesce(new.strasse, '') and coalesce(old.plz, '') = coalesce(new.plz, '')
     and coalesce(old.ort, '') = coalesce(new.ort, '') and coalesce(old.name, '') = coalesce(new.name, '') then return new; end if;
  if old.strasse is null and old.plz is null and old.ort is null then return new; end if;   -- erstmals befüllt
  was := case when coalesce(old.strasse, '') = coalesce(new.strasse, '') and coalesce(old.plz, '') = coalesce(new.plz, '')
              and coalesce(old.ort, '') = coalesce(new.ort, '') then 'Name' else 'Adresse' end;
  if was = 'Adresse' then new.geo_lat := null; new.geo_lon := null; new.geo_stand := null; end if;

  update offerte set adresse_fix = alt
   where kunde_id = new.id and objekt_id is null and adresse_fix is null and coalesce(status, 'offen') <> 'offen';
  get diagnostics n_fix = row_count;
  select count(*), (array_agg(erstellt_von order by erstellt_am desc) filter (where erstellt_von is not null))[1]
    into n_offen, wer
    from offerte where kunde_id = new.id and objekt_id is null and adresse_fix is null and coalesce(status, 'offen') = 'offen';
  insert into kunde_adresse_verlauf (kunde_id, alt, neu, art, quelle, von) values (new.id, alt, kunde_adresse_json(new), 'easybill', 'easybill', null);

  if n_offen > 0 or n_fix > 0 then
    if wer is null then select id into wer from benutzer where rolle = 'admin' and aktiv order by erstellt_am limit 1; end if;
    select l.id into box from pendenz_liste l join pendenz_board b on b.id = l.board_id
     where b.typ = 'person' and b.besitzer_id = wer and l.art_id = 'sammel' limit 1;
    if box is not null then
      insert into pendenz (liste_id, titel, notiz, kunde_id, herkunft, erstellt_von, sortierung)
      values (box,
        was || ' von ' || coalesce(new.name, 'Kunde') || ' in Easybill geändert',
        -- Notiz ist HTML (Editor im Pendenzen-Tool)
        '<p>Neu: ' || replace(replace(concat_ws(', ', new.strasse, concat_ws(' ', new.plz, new.ort)), '<', '&lt;'), '>', '&gt;')
          || '<br>Bisher: ' || replace(replace(concat_ws(', ', old.strasse, concat_ws(' ', old.plz, old.ort)), '<', '&lt;'), '>', '&gt;')
          || '<br>' || n_offen || ' offene Offerte(n) haben die neue ' || was || ', ' || n_fix || ' abgeschlossene behalten die bisherige.'
          || case when was = 'Adresse' then '<br>Umgezogen und die alte Adresse bleibt? In Kontakte beim Kunden unter Objekte «Bisherige Adresse» erfassen.' else '' end || '</p>',
        new.id, 'board', wer, extract(epoch from now()));
    end if;
  end if;
  return new;
end $$;
drop trigger if exists kunde_easybill_aenderung on kunde;
create trigger kunde_easybill_aenderung before update on kunde for each row execute function kunde_easybill_aenderung();

-- ---------------------------------------------------------------- Kundensuche ohne Inaktive (Pendenzen, Planer …)
create or replace function public.kunde_suche(q text, anzahl integer default 20)
 returns table(id uuid, name text, strasse text, plz text, ort text, kundennummer text, easybill_id bigint)
 language sql stable set search_path to 'public'
as $function$
  with w as (select unnest(regexp_split_to_array(lower(trim(coalesce(q, ''))), '\s+')) as wort)
  select k.id,
         coalesce(nullif(trim(k.firma), ''), nullif(trim(concat_ws(' ', k.vorname, k.nachname)), ''), k.name) as name,
         k.strasse, k.plz::text, k.ort, k.kundennummer::text, k.easybill_id::bigint
  from kunde k
  where length(trim(coalesce(q, ''))) >= 2 and not k.inaktiv
    and not exists (select 1 from w where wort <> '' and lower(concat_ws(' ', k.name, k.firma, k.vorname, k.nachname, k.strasse, k.plz, k.ort, k.kundennummer)) not like '%' || wort || '%')
  order by (lower(coalesce(nullif(trim(k.firma), ''), k.nachname, k.name)) like lower(trim(q)) || '%') desc, 2
  limit greatest(1, least(coalesce(anzahl, 20), 100));
$function$;
