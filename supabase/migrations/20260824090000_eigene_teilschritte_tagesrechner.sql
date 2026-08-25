-- ============================================================================
-- "Eigene Teilschritte" beim Tagesrechner (Offerte-Typ Tagessatz): erlauben,
-- pro einzelner Offerte zusaetzliche Teilschritte zu erfassen, die es in der
-- Vorlage nicht gibt - entweder angehaengt an einen bestehenden Arbeitsschritt
-- oder in einem komplett eigenen Arbeitsschritt. Wird NIE in die Vorlage
-- (Tool B) zurueckgeschrieben, existiert ausschliesslich fuer die jeweilige
-- Offerte (on delete cascade).
--
-- Menge pro Ressourcenzeile gilt hier direkt (einmalig fuer den ganzen
-- Teilschritt) statt wie bei Vorlagen-Teilschritten "Tagesleistungsmenge x
-- Anzahl Tage" - darum eine eigene, viel schlankere Tabelle statt die
-- bestehende ressourcenzeile-Tabelle (die haengt zwingend an einem
-- Vorlagen-teilschritt_id/option_id) zu verbiegen.
-- ============================================================================

create table offerte_eigener_arbeitsschritt (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  name text not null,
  reihenfolge integer not null default 0
);
alter table offerte_eigener_arbeitsschritt enable row level security;
create policy offerte_eigener_arbeitsschritt_voller_zugriff on offerte_eigener_arbeitsschritt
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Haengt entweder an einem Vorlagen-Arbeitsschritt (arbeitsschritt_id) ODER
-- an einem offerten-eigenen Arbeitsschritt (eigener_arbeitsschritt_id) - nie
-- beides, nie keines.
create table offerte_eigener_teilschritt (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  arbeitsschritt_id uuid null references arbeitsschritt(id) on delete cascade,
  eigener_arbeitsschritt_id uuid null references offerte_eigener_arbeitsschritt(id) on delete cascade,
  name text not null,
  beschreibung text null,
  reihenfolge integer not null default 0,
  check ((arbeitsschritt_id is null) <> (eigener_arbeitsschritt_id is null))
);
alter table offerte_eigener_teilschritt enable row level security;
create policy offerte_eigener_teilschritt_voller_zugriff on offerte_eigener_teilschritt
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Menge gilt direkt (kein Tagesleistung-Faktor), Kategorie kommt vom Artikel.
create table offerte_eigene_teilschritt_zeile (
  id uuid primary key default gen_random_uuid(),
  eigener_teilschritt_id uuid not null references offerte_eigener_teilschritt(id) on delete cascade,
  artikel_id uuid not null references artikel(id) on delete restrict,
  menge numeric not null default 0,
  reihenfolge integer not null default 0
);
alter table offerte_eigene_teilschritt_zeile enable row level security;
create policy offerte_eigene_teilschritt_zeile_voller_zugriff on offerte_eigene_teilschritt_zeile
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
