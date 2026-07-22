-- ============================================================================
-- Offertentool 2027 - Tagessatz-Modell: automatische Personalkosten pro Tag
--
-- Jeder gebuchte Tag auf einem Arbeitsschritt bedeutet automatisch 1 Vorarbeiter
-- + 1 Gartenarbeiter, je "Tagesleistung" Std (global konfigurierbar). Die
-- Stundensaetze kommen aus 2 fest hinterlegten Artikeln im Artikelstamm (Preis
-- kommt aus artikel.vp_knecht) - gleiches Konfigurationsmuster wie bei der
-- Lieferwagenfahrzeit-Konfiguration (siehe db/lieferwagenfahrt-v1.sql).
-- ============================================================================

create table tagessatz_personal_konfiguration (
  id boolean primary key default true,
  constraint tagessatz_personal_konfiguration_singleton check (id),
  tagesleistung_std numeric not null default 9,
  vorarbeiter_artikel_id uuid null references artikel(id),
  gartenarbeiter_artikel_id uuid null references artikel(id)
);
insert into tagessatz_personal_konfiguration (id) values (true);

alter table tagessatz_personal_konfiguration enable row level security;
create policy tagessatz_personal_konfiguration_lesen on tagessatz_personal_konfiguration for select using (ist_eingeloggter_benutzer());
create policy tagessatz_personal_konfiguration_admin_schreibt on tagessatz_personal_konfiguration for all using (ist_admin()) with check (ist_admin());
