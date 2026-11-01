-- ============================================================================
-- Gruppen & Rechte, Etappe 2b: Vorlagen (Offertentool), Pflege & Service, Nachschlagewerk.
-- Lesen bleibt für alle Eingeloggten offen (andere Tools lesen mit), Schreiben nach Rechten.
-- Grundsatz: niemand verliert, was er heute darf – wo die Vorschlagswerte das geändert
-- hätten, sind die Werte unten angepasst (in der Verwaltung jederzeit änderbar).
-- ============================================================================

create or replace function recht_darf(p_tool text, p_bereich text, p_aktion text) returns boolean
language sql stable security definer set search_path = public as $$
  select recht_wert(p_tool, p_bereich, p_aktion) not in ('K', 'N');
$$;

-- Tabelle auf «Lesen offen, Schreiben wenn Bedingung» umstellen (ersetzt alle bisherigen Policies)
create or replace function _rechte_tabelle(t text, schreiben text) returns void language plpgsql as $$
declare p record;
begin
  for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
    execute format('drop policy %I on %I', p.policyname, t);
  end loop;
  execute format('alter table %I enable row level security', t);
  execute format('create policy %I on %I for select using (ist_eingeloggter_benutzer())', t || '_lesen', t);
  execute format('create policy %I on %I for all using (%s) with check (%s)', t || '_schreiben', t, schreiben, schreiben);
end $$;

-- Werte: heutige Möglichkeiten beibehalten -----------------------------------
with soll(schluessel, tool, bereich, aktion, wert) as (values
  -- Vorlagen (Tool B / Vorlagen & Berechnung): Büro bearbeitet heute mit
  ('buero', 'offerten', 'vorlagen', 'erstellen', 'J'), ('buero', 'offerten', 'vorlagen', 'bearbeiten', 'A'), ('buero', 'offerten', 'vorlagen', 'loeschen', 'A'),
  -- Pflegekategorien: heute nur Büro/Admin
  ('buero', 'pflege', 'kategorien', 'erstellen', 'J'), ('buero', 'pflege', 'kategorien', 'bearbeiten', 'A'), ('buero', 'pflege', 'kategorien', 'loeschen', 'A'),
  ('va_pflege', 'pflege', 'kategorien', 'erstellen', 'N'), ('va_pflege', 'pflege', 'kategorien', 'bearbeiten', 'K'), ('va_pflege', 'pflege', 'kategorien', 'loeschen', 'K'),
  -- Nachschlagewerk-Einträge: heute nur Büro/Admin
  ('va_bau', 'wissen', 'eintraege', 'erstellen', 'N'), ('va_bau', 'wissen', 'eintraege', 'bearbeiten', 'K'),
  ('va_pflege', 'wissen', 'eintraege', 'erstellen', 'N'), ('va_pflege', 'wissen', 'eintraege', 'bearbeiten', 'K'),
  ('pool', 'wissen', 'eintraege', 'erstellen', 'N'), ('pool', 'wissen', 'eintraege', 'bearbeiten', 'K'),
  -- Maschinen-Service: abhaken (= erstellen) wie heute für alle, Service-Vorgaben ändern nur Büro
  ('va_bau', 'wissen', 'service', 'bearbeiten', 'K'), ('va_pflege', 'wissen', 'service', 'bearbeiten', 'K'), ('pool', 'wissen', 'service', 'bearbeiten', 'K'),
  ('buero', 'wissen', 'service', 'bearbeiten', 'A'))
insert into recht_eintrag (gruppe_id, tool_key, bereich_key, aktion, wert)
select g.id, s.tool, s.bereich, s.aktion, s.wert from soll s join recht_gruppe g on g.schluessel = s.schluessel
on conflict (gruppe_id, tool_key, bereich_key, aktion) do update set wert = excluded.wert, geaendert_am = now();

-- Offertentool › Vorlagen (nur Tabellen, die bisher alle schreiben durften; Admin-Tabellen bleiben Admin)
select _rechte_tabelle(t, $$recht_darf('offerten', 'vorlagen', 'bearbeiten')$$)
from unnest(array['arbeitsschritt', 'teilschritt', 'auswahlfeld', 'auswahloption', 'ressourcenzeile', 'eingabefeld_tabelle_spalte']) t;

-- Pflege › Kunden (Objekte, Kategorien beim Kunden, Zuständige, Arbeiten)
select _rechte_tabelle(t, $$recht_darf('pflege', 'kunden', 'bearbeiten')$$)
from unnest(array['pflege_kunde', 'pflege_objekt', 'pflege_kunde_kategorie_zustaendig', 'pflege_kunde_arbeit']) t;
-- Kategorie beim Kunden: auch aus der Handy-Ansicht (Einsätze) bearbeitbar
select _rechte_tabelle('pflege_kunde_kategorie', $$(recht_darf('pflege', 'kunden', 'bearbeiten') or recht_darf('pflege', 'jahresplan', 'bearbeiten'))$$);
-- Pflege › Einsätze (Handy): Status, Fotos, Dokumente – auch der Planer setzt Status
select _rechte_tabelle(t, $$(recht_darf('pflege', 'jahresplan', 'bearbeiten') or recht_darf('pflege', 'kunden', 'bearbeiten') or recht_darf('plan', 'einsaetze', 'bearbeiten'))$$)
from unnest(array['pflege_einsatz_status', 'pflege_foto', 'pflege_dokument', 'pflege_foto_kategorie']) t;
-- Pflege › Kategorien (Einstellungen)
select _rechte_tabelle(t, $$recht_darf('pflege', 'kategorien', 'bearbeiten')$$)
from unnest(array['pflege_kategorie', 'pflege_feld', 'pflege_arbeit', 'pflege_tabelle', 'pflege_tabelle_spalte', 'pflege_tag', 'pflege_region', 'pflege_region_plz', 'pflege_dokument_kategorie']) t;

-- Nachschlagewerk › Einträge (inkl. Exemplare, Felder, Kategorien, Listen, Merkmale, Bereiche)
select _rechte_tabelle(t, $$recht_darf('wissen', 'eintraege', 'bearbeiten')$$)
from unnest(array['wissen_eintrag', 'wissen_exemplar', 'wissen_feld', 'wissen_kategorie', 'wissen_liste', 'wissen_merkmal', 'wissen_bereich']) t;
-- Nachschlagewerk › Maschinen-Service: Vorgaben ändern / erledigt erfassen
select _rechte_tabelle('wissen_service', $$recht_darf('wissen', 'service', 'bearbeiten')$$);
select _rechte_tabelle('wissen_service_erledigt', $$recht_darf('wissen', 'service', 'erstellen')$$);

drop function _rechte_tabelle(text, text);
