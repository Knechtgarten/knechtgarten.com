-- ============================================================================
-- Gruppen & Rechte, Etappe 2b: Einsatzplaner.
-- Wunsch (2026-11-01): Admin und Projektleiter / Büroteam ändern alles.
-- Gartenpflege (Vorarbeiter Pflege) und Poolservice ändern nur ihre eigene Zeile
-- (+ die Titelzeile ihrer Gruppe, das regelt die Oberfläche). Gartenbau und
-- Hilfsarbeitende: nur ansehen.
-- ============================================================================

-- Werte in Gruppen & Rechte (Einsatzplaner › Einsätze)
with soll(schluessel, aktion, wert) as (values
  ('buero','anzeigen','A'), ('buero','erstellen','J'), ('buero','bearbeiten','A'), ('buero','loeschen','A'),
  ('va_bau','anzeigen','A'), ('va_bau','erstellen','N'), ('va_bau','bearbeiten','K'), ('va_bau','loeschen','K'),
  ('va_pflege','anzeigen','A'), ('va_pflege','erstellen','J'), ('va_pflege','bearbeiten','E'), ('va_pflege','loeschen','E'),
  ('pool','anzeigen','A'), ('pool','erstellen','J'), ('pool','bearbeiten','E'), ('pool','loeschen','E'),
  ('hilf','anzeigen','A'), ('hilf','erstellen','N'), ('hilf','bearbeiten','K'), ('hilf','loeschen','K'))
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, 'plan', 'einsaetze', s.aktion, s.wert from soll s join recht_gruppe g on g.schluessel = s.schluessel
on conflict (gruppe_id, tool_key, bereich_key, aktion) do update set wert = excluded.wert, geaendert_am = now();

-- Darf der angemeldete Benutzer die Zeile dieser Planer-Person ändern?
-- Alle = jede Zeile, Eigene = eigene Zeile, Gruppe = Zeilen der eigenen Planer-Gruppe, Keine = nein.
-- (Benutzer ohne Gruppe: wie bisher Büro/Admin alles, sonst eigene Zeile.)
create or replace function planer_darf_person(p uuid) returns boolean
language plpgsql stable security definer set search_path = public as $$
declare b benutzer; w text;
begin
  select * into b from benutzer where id = auth.uid() and aktiv and rolle is not null;
  if b.id is null then return false; end if;
  if b.recht_gruppe_id is null then
    return b.rolle in ('admin', 'buero_team')
      or exists (select 1 from planer_person pp where pp.id = p and pp.benutzer_id = b.id);
  end if;
  w := recht_wert('plan', 'einsaetze', 'bearbeiten');
  if w = 'A' then return true; end if;
  if w = 'E' then return exists (select 1 from planer_person pp where pp.id = p and pp.benutzer_id = b.id); end if;
  if w = 'G' then return exists (
    select 1 from planer_person ziel join planer_person ich on ich.gruppe_id = ziel.gruppe_id
    where ziel.id = p and ich.benutzer_id = b.id and ich.aktiv); end if;
  return false;
end $$;
