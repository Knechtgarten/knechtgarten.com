-- ============================================================================
-- Offertentool 2027 - Korrektur einzelner Zeilen in der Kostentabelle
--
-- Die Zeilen in der Kostentabelle werden bei jeder Neuberechnung live aus dem
-- Formel-/Tagessatz-Katalog zusammengerechnet (nicht als eigene Datensaetze
-- gespeichert). Damit ein berechneter Wert (Menge oder Preis) korrigiert
-- werden kann, OHNE den urspruenglich berechneten Wert zu verlieren, wird die
-- Korrektur getrennt pro Zeile gespeichert und beim Anzeigen ueberlagert.
--
-- zeilen_schluessel identifiziert eine Zeile stabil ueber Speichervorgaenge
-- hinweg (z.B. "personal:Baggerfuehrer", "maschine:budget",
-- "material:Fundament") - siehe addRow()/KAT_ORDER-Schleife in den Tools.
--
-- geloescht = Zeile wurde vom Nutzer entfernt (durchgestrichen, zaehlt nicht
-- mehr im Total, bleibt aber sichtbar und ist wiederherstellbar).
-- ============================================================================

create table offerte_zeilen_korrektur (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  zeilen_schluessel text not null,
  menge_korrektur numeric null,
  preis_korrektur numeric null,
  geloescht boolean not null default false,
  unique (offerte_id, zeilen_schluessel)
);

alter table offerte_zeilen_korrektur enable row level security;

create policy "voller Zugriff fuer jeden eingeloggten Benutzer"
  on offerte_zeilen_korrektur for all
  using (ist_eingeloggter_benutzer())
  with check (ist_eingeloggter_benutzer());
