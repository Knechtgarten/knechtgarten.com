-- ============================================================================
-- Offertentool 2027 - Sonderpositionen in der Ressourcenzeile
-- Eine Ressourcenzeile kann statt einem festen Artikel auch eine "Herkunft"
-- aus einem der folgenden Kataloge referenzieren - die Preisfindung passiert
-- dann zur Berechnungszeit in Tool A statt fix hier zu stehen:
--   - staffelgruppe: Menge-Formel bestimmt den Lookup-Wert, gesucht wird die
--     passende Staffelstufe (siehe preisfindung-phase1-v1.sql).
--   - zonengruppe: Lookup ausschliesslich ueber die Kunde-PLZ, keine Menge
--     noetig.
--   - sonderposition_typ (neu, dieser Migration): Katalog fuer Faelle mit
--     echter Spezial-Rechenlogik (z.B. "Sonderfahrt zur Baustelle",
--     "Baggertransport") - hier nur Name+Erklaerung, die eigentliche Logik
--     wird pro Fall separat programmiert (kein Self-Service-Baukasten).
-- ============================================================================

create table sonderposition_typ (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  erklaerung text null,
  erstellt_am timestamptz not null default now()
);

alter table sonderposition_typ enable row level security;
create policy sonderposition_typ_lesen on sonderposition_typ for select using (ist_eingeloggter_benutzer());
create policy sonderposition_typ_admin_schreibt on sonderposition_typ for all using (ist_admin()) with check (ist_admin());

-- Ressourcenzeile: drei neue, alternative Quellen zum bestehenden artikel_id.
alter table ressourcenzeile add column staffelgruppe_id uuid null references staffelgruppe(id) on delete restrict;
alter table ressourcenzeile add column zonengruppe_id uuid null references zonengruppe(id) on delete restrict;
alter table ressourcenzeile add column sonderposition_typ_id uuid null references sonderposition_typ(id) on delete restrict;

alter table ressourcenzeile add constraint ressourcenzeile_genau_eine_quelle_check
  check (
    (case when artikel_id is not null then 1 else 0 end
     + case when staffelgruppe_id is not null then 1 else 0 end
     + case when zonengruppe_id is not null then 1 else 0 end
     + case when sonderposition_typ_id is not null then 1 else 0 end) = 1
  );
