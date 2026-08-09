-- ============================================================================
-- Offertentool 2027 - Freitext-Position als Vorlagen-Baustein (Tool B), nicht
-- nur als rein manuelle "Eigene Position" (Tool A).
--
-- Anwendungsfall: eine wiederkehrende, aber preislich variable Position wie
-- "Beckenlieferung" - der Name ist immer gleich, Menge/Preis sind aber von
-- Offerte zu Offerte verschieden und werden erst beim Erstellen eingetragen
-- (manchmal schon zum Zeitpunkt der Vorlagen-Erstellung bekannt, manchmal
-- nicht - beides erlaubt, Menge/Preis-Vorschlag bleiben darum optional).
--
-- Bewusst KEINE Erweiterung von ressourcenzeile: eine Freitext-Position hat
-- keinen Artikel-/Formel-Bezug und keine automatische Berechnung - sie soll
-- exakt wie die bereits bestehende "Eigene Position" (offerte_eigene_zeile)
-- funktionieren, nur dass Tool A sie automatisch pro Teilflaeche vorbefuellt,
-- sobald die zugehoerige Option/der Teilschritt aktiv ist, statt dass der
-- Mitarbeiter sie jedes Mal von Hand neu anlegen muss.
-- ============================================================================

create table option_freitext_vorlage (
  id uuid primary key default gen_random_uuid(),
  option_id uuid null references auswahloption(id) on delete cascade,
  teilschritt_id uuid null references teilschritt(id) on delete cascade,
  kategorie text not null check (kategorie in ('personal','maschine','logistik','material')),
  bezeichnung text not null,
  einheit text null,
  notiz text null,
  menge_vorschlag numeric null,
  preis_vorschlag numeric null,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now(),
  constraint option_freitext_vorlage_genau_ein_kontext check (
    (option_id is not null and teilschritt_id is null) or (option_id is null and teilschritt_id is not null)
  )
);
alter table option_freitext_vorlage enable row level security;
create policy option_freitext_vorlage_lesen on option_freitext_vorlage for select using (ist_eingeloggter_benutzer());
create policy option_freitext_vorlage_admin_schreibt on option_freitext_vorlage for all using (ist_admin()) with check (ist_admin());

-- Rueckverweis auf die Vorlage, aus der eine Eigene Position automatisch
-- entstanden ist - wird geloescht (auf null gesetzt), die bestehende Zeile
-- bleibt als ganz normale, unabhaengige Eigene Position stehen.
alter table offerte_eigene_zeile add column freitext_vorlage_id uuid null references option_freitext_vorlage(id) on delete set null;
