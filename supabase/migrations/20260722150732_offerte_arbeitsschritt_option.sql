-- ============================================================================
-- Offertentool 2027 - Tagessatz-Offerten auf Formel-Struktur umstellen (Teil 2).
--
-- Tagessatz-Arbeitsschritte koennen kuenftig (wie Formel-Teilschritte) ein
-- Auswahlfeld mit Optionen haben (z.B. "Fahrzeug: Bagger M/L/S"). Diese Tabelle
-- speichert pro Offerte, welche Option je Arbeitsschritt gewaehlt wurde -
-- gleiches Muster wie das bestehende teilflaeche_auswahl bei Formel-Offerten.
-- ============================================================================

create table offerte_arbeitsschritt_option (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  arbeitsschritt_id uuid not null references arbeitsschritt(id) on delete restrict,
  option_id uuid not null references auswahloption(id) on delete restrict,
  unique (offerte_id, arbeitsschritt_id, option_id)
);

alter table offerte_arbeitsschritt_option enable row level security;
create policy offerte_arbeitsschritt_option_voller_zugriff on offerte_arbeitsschritt_option
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
