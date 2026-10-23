-- ============================================================================
-- Wissen & Geräte: Merkmal-Vorschläge für die Tabellen «Technische Daten» /
-- Angaben / Verwaltung (Seite Einstellungen, nur Büro pflegt sie).
-- ============================================================================
create table if not exists wissen_merkmal (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  sortierung int not null default 0
);
alter table wissen_merkmal enable row level security;
drop policy if exists wissen_merkmal_lesen on wissen_merkmal;
drop policy if exists wissen_merkmal_buero on wissen_merkmal;
create policy wissen_merkmal_lesen on wissen_merkmal for select using (ist_eingeloggter_benutzer());
create policy wissen_merkmal_buero on wissen_merkmal for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

insert into wissen_merkmal (name, sortierung)
select n, i * 10 from unnest(array['Hersteller / Modell', 'Gewicht', 'Breite', 'Höhe', 'Länge', 'Leistung', 'Treibstoff',
  'Anhängelast', 'Nutzlast', 'Arbeitsbreite', 'Akku', 'Anschaffungsjahr', 'Seriennummer', 'Kontrollschild', 'Fahrzeugprüfung']) with ordinality t(n, i)
on conflict (name) do nothing;
