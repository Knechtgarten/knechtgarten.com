-- ============================================================================
-- Offertentool 2027 - Preisverlauf pro Artikel. Jede Aenderung des
-- Einstandspreises (egal ob manuell im Artikelstamm oder ueber den neuen
-- Lieferanten-Datenabgleich) wird hier als eigene Zeile festgehalten, damit
-- alte Preise jederzeit nachvollziehbar/vergleichbar bleiben.
-- ============================================================================

create table artikel_preis_verlauf (
  id uuid primary key default gen_random_uuid(),
  artikel_id uuid not null references artikel(id) on delete cascade,
  alter_preis numeric null,
  neuer_preis numeric not null,
  quelle text not null check (quelle in ('artikelstamm','abgleich')),
  methode text null,
  lieferant_id uuid null references lieferant(id) on delete set null,
  geaendert_am timestamptz not null default now()
);

alter table artikel_preis_verlauf enable row level security;
create policy artikel_preis_verlauf_lesen on artikel_preis_verlauf for select using (ist_eingeloggter_benutzer());
create policy artikel_preis_verlauf_schreiben on artikel_preis_verlauf for insert with check (ist_eingeloggter_benutzer());
