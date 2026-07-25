-- ============================================================================
-- Offertentool 2027 - Eigene Links auf der Tools-Startseite: jeder Benutzer
-- kann sich am Ende seiner Kachel-Einstellungen eigene Seiten (Titel + URL)
-- hinzufuegen. Hintergrundfarbe ist bewusst NICHT waehlbar (fest Navy, die
-- 4. Farbe neben Blau/Gruen/Grau) - das bleibt dem Admin fuer die kuenftigen
-- offiziellen externen Tools (Gmail, Easybill usw.) vorbehalten.
--
-- Sichtbarkeit/Reihenfolge dieser Links laeuft ueber die bereits bestehende
-- benutzer_kachel_einstellung-Tabelle (kachel_key = "link:" + id) - kein
-- Sonderfall noetig, siehe app/index.html.
-- ============================================================================

create table benutzer_eigener_link (
  id uuid primary key default gen_random_uuid(),
  benutzer_id uuid not null references benutzer(id) on delete cascade,
  titel text not null,
  url text not null
);

alter table benutzer_eigener_link enable row level security;
create policy benutzer_eigener_link_eigene on benutzer_eigener_link
  for all using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());
