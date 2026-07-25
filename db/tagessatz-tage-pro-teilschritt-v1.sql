-- ============================================================================
-- Offertentool 2027 - Tagesbedarf neu pro Teilschritt statt pro Arbeitsschritt.
--
-- Der Arbeitsschritt ist nur noch die aufklappbare Gruppierung (analog zum
-- Formel-Modell). Die effektiven Zahlen (Tage, Auswahloption) werden auf
-- Ebene der Teilschritte erfasst - ein Arbeitsschritt zeigt nur die
-- schreibgeschuetzte Summe seiner Teilschritt-Tage.
--
-- Ersetzt fuer Tagessatz-Offerten offerte_arbeitsschritt_tage/-_option. Die
-- alten Tabellen bleiben unangetastet (kein destruktives Loeschen), werden
-- von der App aber nicht mehr verwendet.
-- ============================================================================

create table offerte_teilschritt_tage (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  teilschritt_id uuid not null references teilschritt(id) on delete restrict,
  anzahl_tage numeric not null default 0,
  unique (offerte_id, teilschritt_id)
);
alter table offerte_teilschritt_tage enable row level security;
create policy offerte_teilschritt_tage_voller_zugriff on offerte_teilschritt_tage
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

create table offerte_teilschritt_option (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  teilschritt_id uuid not null references teilschritt(id) on delete restrict,
  option_id uuid not null references auswahloption(id) on delete restrict,
  unique (offerte_id, teilschritt_id, option_id)
);
alter table offerte_teilschritt_option enable row level security;
create policy offerte_teilschritt_option_voller_zugriff on offerte_teilschritt_option
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
