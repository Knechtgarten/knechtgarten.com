-- Fläche-/Körper-Rechner im "Notizen & Berechnungen"-Panel (Tool A + Tool A2):
-- Nutzer erfasst über Icon-Klick Gartenelemente (Blumenbeet, Pflanzgefäss usw.)
-- mit Text, Anzahl und formspezifischen Massen, App berechnet Fläche/Volumen.
-- Reines Notiz-Hilfsmittel, kein Bezug zum Ressourcen-Mengensystem (menge_ausdruck).
-- Gilt für jeden Offertentyp (Formel und Tagessatz gleichermassen).

create table offerte_geometrie_element (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  form_typ text not null,
  bezeichnung text not null,
  anzahl numeric not null default 1,
  masse jsonb not null default '{}'::jsonb,
  flaeche numeric,
  volumen numeric,
  reihenfolge integer not null default 0,
  erstellt_am timestamptz not null default now()
);

alter table offerte_geometrie_element enable row level security;
create policy offerte_geometrie_element_voller_zugriff on offerte_geometrie_element
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
