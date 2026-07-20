-- ============================================================================
-- Offertentool 2027 - Preisfindung Phase 3: Lieferwagenfahrzeit
-- Berechnet einmal pro Offerte (nicht pro Bauteil) anhand der Kunde-PLZ ueber
-- die Google Maps Distance Matrix API. Zwei Ansaetze (Zeit/Distanz) werden
-- immer beide berechnet, der Nutzer waehlt pro Offerte, welcher zaehlt.
-- ============================================================================

-- Singleton-Konfiguration (genau eine Zeile): Herkunftsadresse + welche
-- Artikel den Stunden- bzw. km-Ansatz liefern (Preis kommt aus artikel.vp_knecht).
create table lieferwagen_konfiguration (
  id boolean primary key default true,
  constraint lieferwagen_konfiguration_singleton check (id),
  herkunft_adresse text not null default 'Badhaus 42, 3615 Heimenschwand, Schweiz',
  stundenansatz_artikel_id uuid null references artikel(id),
  km_ansatz_artikel_id uuid null references artikel(id)
);
insert into lieferwagen_konfiguration (id) values (true);

alter table lieferwagen_konfiguration enable row level security;
create policy lieferwagen_konfiguration_lesen on lieferwagen_konfiguration for select using (ist_eingeloggter_benutzer());
create policy lieferwagen_konfiguration_admin_schreibt on lieferwagen_konfiguration for all using (ist_admin()) with check (ist_admin());

-- Pro Offerte gespeicherte Auswahl, welcher Ansatz gilt (Default 'zeit').
alter table offerte add column lieferwagen_modus text not null default 'zeit'
  check (lieferwagen_modus in ('zeit','distanz'));
