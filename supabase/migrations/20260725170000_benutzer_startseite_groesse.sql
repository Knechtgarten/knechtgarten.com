-- ============================================================================
-- Offertentool 2027 - Kachel-Groesse auf der Tools-Startseite, pro Benutzer.
--
-- Erste Etappe des Ausbaus der Startseite zu einem allgemeinen Tool-Launcher
-- (interne Tools, Admin-gepflegte externe Tools wie Gmail/Easybill, spaeter
-- eigene Links pro Benutzer). Diese Migration liefert nur die Groessen-
-- Einstellung - der Rest folgt in separaten, spaeteren Migrationen.
-- ============================================================================

create table benutzer_startseite_einstellung (
  benutzer_id uuid primary key references benutzer(id) on delete cascade,
  groesse text not null default 'gross' check (groesse in ('gross', 'mittel', 'klein'))
);

alter table benutzer_startseite_einstellung enable row level security;
create policy benutzer_startseite_einstellung_eigene on benutzer_startseite_einstellung
  for all using (benutzer_id = auth.uid()) with check (benutzer_id = auth.uid());
