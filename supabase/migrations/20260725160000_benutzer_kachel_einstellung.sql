-- ============================================================================
-- Offertentool 2027 - Persoenliche Kachel-Einstellung pro Benutzer.
--
-- Jeder eingeloggte Benutzer kann auf der Tools-Startseite (index.html)
-- selbst entscheiden, welche der fuer ihn/seine Rolle bereits freigeschalteten
-- Kacheln er sehen moechte und in welcher Reihenfolge - unabhaengig von
-- modul_sichtbarkeit, die weiterhin nur die Rollen-Freischaltung durch den
-- Admin steuert. Ohne eigene Eintraege gilt der Standard: alle freigeschalteten
-- Kacheln sichtbar, Standard-Reihenfolge.
-- ============================================================================

create table benutzer_kachel_einstellung (
  benutzer_id uuid not null references benutzer(id) on delete cascade,
  kachel_key text not null,
  sichtbar boolean not null default true,
  reihenfolge int not null default 0,
  primary key (benutzer_id, kachel_key)
);

alter table benutzer_kachel_einstellung enable row level security;
create policy benutzer_kachel_einstellung_eigene on benutzer_kachel_einstellung
  for all using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());
