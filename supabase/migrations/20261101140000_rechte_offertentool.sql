-- ============================================================================
-- Gruppen & Rechte, Etappe 2b: Offertentool in der Datenbank absichern.
--
-- recht_wert(tool, bereich, aktion)  -> Wert der Gruppe des angemeldeten Benutzers
--   ('K','E','G','A' bzw. 'J','N'). Administrator und Personen ohne Gruppe
--   (alte Konten) dürfen weiter alles; nicht freigeschaltete Konten nichts.
-- recht_ok(tool, bereich, aktion, besitzer) -> true/false mit Eigene/Gruppe:
--   E = besitzer ist man selbst, G = besitzer ist in der gleichen Gruppe.
--   Ohne Besitzer (alte Offerten, erstellt_von leer) zählt nur «Alle».
--
-- Offerten (+ alle offerte_*-Tabellen): Lesen/Erstellen/Bearbeiten/Löschen nach
--   Bereich offerten.offerten, Besitzer = offerte.erstellt_von.
-- Kunden und Artikel: Lesen bleibt für alle offen (Planer, Pflege, Nachschlagewerk
--   und die Offerten-Eingabe brauchen sie), Schreiben nach Rechten. Kunden dürfen
--   auch mit den Rechten aus Pflege & Service › Pflegekunden geschrieben werden.
-- ============================================================================

create or replace function recht_wert(p_tool text, p_bereich text, p_aktion text) returns text
language plpgsql stable security definer set search_path = public as $$
declare b benutzer; g recht_gruppe; w text;
  jn boolean := p_aktion in ('erstellen', 'an', 'sichtbar');
begin
  select * into b from benutzer where id = auth.uid() and aktiv and rolle is not null;
  if b.id is null then return case when jn then 'N' else 'K' end; end if;
  if b.rolle = 'admin' or b.recht_gruppe_id is null then return case when jn then 'J' else 'A' end; end if;
  select * into g from recht_gruppe where id = b.recht_gruppe_id;
  if g.ist_admin then return case when jn then 'J' else 'A' end; end if;
  select wert into w from recht_eintrag
    where gruppe_id = b.recht_gruppe_id and tool_key = p_tool and bereich_key = p_bereich and aktion = p_aktion;
  return coalesce(w, case when jn then 'N' else 'K' end);
end $$;

create or replace function recht_ok(p_tool text, p_bereich text, p_aktion text, p_besitzer uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare w text := recht_wert(p_tool, p_bereich, p_aktion);
begin
  if w in ('A', 'J') then return true; end if;
  if w = 'E' then return p_besitzer is not null and p_besitzer = auth.uid(); end if;
  if w = 'G' then return p_besitzer is not null and exists (
    select 1 from benutzer a join benutzer o on o.recht_gruppe_id = a.recht_gruppe_id
    where a.id = auth.uid() and o.id = p_besitzer and a.recht_gruppe_id is not null); end if;
  return false;
end $$;

-- Offerten -------------------------------------------------------------------
drop policy if exists offerte_voller_zugriff on offerte;
drop policy if exists offerte_lesen on offerte;
drop policy if exists offerte_erstellen on offerte;
drop policy if exists offerte_bearbeiten on offerte;
drop policy if exists offerte_loeschen on offerte;
create policy offerte_lesen on offerte for select using (recht_ok('offerten', 'offerten', 'anzeigen', erstellt_von));
create policy offerte_erstellen on offerte for insert with check (recht_wert('offerten', 'offerten', 'erstellen') = 'J');
create policy offerte_bearbeiten on offerte for update
  using (recht_ok('offerten', 'offerten', 'bearbeiten', erstellt_von))
  with check (recht_ok('offerten', 'offerten', 'bearbeiten', erstellt_von));
create policy offerte_loeschen on offerte for delete using (recht_ok('offerten', 'offerten', 'loeschen', erstellt_von));

-- Inhalte einer Offerte: sichtbar, wenn die Offerte sichtbar ist; ändern, wenn man die Offerte bearbeiten darf
do $$
declare t text; p record;
begin
  for t in select c.table_name from information_schema.columns c
           where c.table_schema = 'public' and c.column_name = 'offerte_id' and c.table_name like 'offerte\_%'
  loop
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on %I', p.policyname, t);
    end loop;
    execute format('alter table %I enable row level security', t);
    execute format('create policy %I on %I for select using (exists (select 1 from offerte o where o.id = %I.offerte_id))',
      t || '_lesen', t, t);
    execute format('create policy %I on %I for all using (exists (select 1 from offerte o where o.id = %I.offerte_id and recht_ok(''offerten'', ''offerten'', ''bearbeiten'', o.erstellt_von))) with check (exists (select 1 from offerte o where o.id = %I.offerte_id and recht_ok(''offerten'', ''offerten'', ''bearbeiten'', o.erstellt_von)))',
      t || '_schreiben', t, t, t);
  end loop;
end $$;

-- Kunden ---------------------------------------------------------------------
drop policy if exists kunde_voller_zugriff on kunde;
drop policy if exists kunde_lesen on kunde;
drop policy if exists kunde_erstellen on kunde;
drop policy if exists kunde_bearbeiten on kunde;
drop policy if exists kunde_loeschen on kunde;
create policy kunde_lesen on kunde for select using (ist_eingeloggter_benutzer());
create policy kunde_erstellen on kunde for insert with check (
  recht_wert('offerten', 'kunden', 'erstellen') = 'J' or recht_wert('pflege', 'kunden', 'erstellen') = 'J');
create policy kunde_bearbeiten on kunde for update
  using (recht_wert('offerten', 'kunden', 'bearbeiten') <> 'K' or recht_wert('pflege', 'kunden', 'bearbeiten') <> 'K')
  with check (recht_wert('offerten', 'kunden', 'bearbeiten') <> 'K' or recht_wert('pflege', 'kunden', 'bearbeiten') <> 'K');
create policy kunde_loeschen on kunde for delete using (
  recht_wert('offerten', 'kunden', 'loeschen') <> 'K' or recht_wert('pflege', 'kunden', 'loeschen') <> 'K');

-- Artikel --------------------------------------------------------------------
drop policy if exists artikel_voller_zugriff on artikel;
drop policy if exists artikel_erstellen on artikel;
drop policy if exists artikel_bearbeiten on artikel;
drop policy if exists artikel_loeschen on artikel;
-- artikel_lesen (alle Eingeloggten) bleibt bestehen
create policy artikel_erstellen on artikel for insert with check (recht_wert('offerten', 'artikel', 'erstellen') = 'J');
create policy artikel_bearbeiten on artikel for update
  using (recht_wert('offerten', 'artikel', 'bearbeiten') <> 'K') with check (recht_wert('offerten', 'artikel', 'bearbeiten') <> 'K');
create policy artikel_loeschen on artikel for delete using (recht_wert('offerten', 'artikel', 'loeschen') <> 'K');

-- Für «Gruppe» in der Oberfläche: IDs aller Personen in meiner Gruppe (auch für Nicht-Admins lesbar)
create or replace function meine_gruppen_mitglieder() returns setof uuid
language sql stable security definer set search_path = public as $$
  select o.id from benutzer a join benutzer o on o.recht_gruppe_id = a.recht_gruppe_id
  where a.id = auth.uid() and a.recht_gruppe_id is not null;
$$;
