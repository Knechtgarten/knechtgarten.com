-- ============================================================================
-- Offertentool 2027 - Eigene Zeile pro Abschnitt in der Kostentabelle
--
-- Pro Kategorie (Personal/Maschine/Logistik/Material) kann der Nutzer direkt
-- in der Kostentabelle eine oder mehrere freie Positionen erfassen (Bezeichnung,
-- Menge, Einheit, Preis) - unabhaengig vom Formel-/Tagessatz-Katalog.
-- Gilt fuer beide Offertentools (Tool A Pool/Formel und Tool A2 Allgemein).
-- ============================================================================

create table offerte_eigene_zeile (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  kategorie text not null,
  bezeichnung text not null default '',
  menge numeric not null default 1,
  einheit text not null default '',
  preis numeric not null default 0,
  reihenfolge int not null default 0
);

alter table offerte_eigene_zeile enable row level security;

create policy "voller Zugriff fuer jeden eingeloggten Benutzer"
  on offerte_eigene_zeile for all
  using (ist_eingeloggter_benutzer())
  with check (ist_eingeloggter_benutzer());
