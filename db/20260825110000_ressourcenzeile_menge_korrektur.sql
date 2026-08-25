-- ============================================================================
-- Tagesrechner: Gesamtmenge einer Ressourcenzeile innerhalb eines
-- Vorlagen-Teilschritts pro Offerte ueberschreiben koennen, ohne die
-- Tagesleistungsmenge in der Vorlage (Tool B) zu aendern - das wuerde sonst
-- alle anderen Offerten mit demselben Offertentyp mitbetreffen.
--
-- Die Korrektur ist ein ABSOLUTER Wert (die fertige Gesamtmenge, nicht ein
-- Tagessatz) und bleibt bestehen, auch wenn die Anzahl Tage des Teilschritts
-- spaeter geaendert wird - siehe Stift-Icon-Markierung in
-- tool-a2-allgemein-live-v1.html (renderTagessatzInhalt/ladeRessourcenzeilenKorrekturen).
-- ============================================================================

create table offerte_ressourcenzeile_korrektur (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  ressourcenzeile_id uuid not null references ressourcenzeile(id) on delete cascade,
  menge numeric not null,
  unique (offerte_id, ressourcenzeile_id)
);
alter table offerte_ressourcenzeile_korrektur enable row level security;
create policy offerte_ressourcenzeile_korrektur_voller_zugriff on offerte_ressourcenzeile_korrektur
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
