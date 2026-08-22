-- ============================================================================
-- Korrektur zu 20260822100000: "Zusatztext" war als fixer, admin-gepflegter
-- Text auf eingabefeld angelegt - macht aber keinen Sinn, da der Hinweis
-- (z.B. "Vor dem Haus") pro Offerte unterschiedlich ist, nicht pro Vorlage.
-- Jetzt analog zu flaechenformel_moeglich: eingabefeld bekommt nur noch ein
-- Haekchen ("ermoeglicht einen Zusatztext"), der eigentliche Text wird pro
-- Offerte im Konfigurator (Tool A) erfasst und in einer neuen Tabelle
-- gespeichert.
-- ============================================================================

alter table eingabefeld drop column zusatztext;
alter table eingabefeld add column zusatztext_moeglich boolean not null default false;

create table offerte_eingabefeld_notiz (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  eingabefeld_id uuid not null references eingabefeld(id) on delete restrict,
  notiz text not null,
  unique (offerte_id, eingabefeld_id)
);
alter table offerte_eingabefeld_notiz enable row level security;
create policy offerte_eingabefeld_notiz_voller_zugriff on offerte_eingabefeld_notiz
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());
