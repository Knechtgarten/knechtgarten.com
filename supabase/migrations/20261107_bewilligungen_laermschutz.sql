-- Bewilligungen: Lärmschutznachweis für Luft/Wasser-Wärmepumpen (Berechnung nach Cercle Bruit Vollzugshilfe 6.21)
-- Wärmepumpen-Katalog mit den Schallangaben aus den Datenblättern; pro Gesuch die gewählten Werte in bewilligung.laerm.

create table if not exists bew_waermepumpe (
  id uuid primary key default gen_random_uuid(),
  hersteller text not null, modell text not null,
  heiz_a2_kw numeric, lwa_a2_db numeric,          -- Heizleistung / Schallleistung bei A2 (Teillast nach EN14825)
  heiz_max_kw numeric, lwa_erp_db numeric,        -- maximale Heizleistung A-7/W35 / Schallleistung nach ErP (A7/W47-55)
  heiz_fluester_kw numeric, lwa_fluester_db numeric,  -- bei A2 im Flüstermodus
  aktiv boolean not null default true, erstellt_am timestamptz not null default now(),
  unique (hersteller, modell)
);
alter table bew_waermepumpe enable row level security;
drop policy if exists bew_wp_lesen on bew_waermepumpe;
create policy bew_wp_lesen on bew_waermepumpe for select to authenticated using (ist_buero_oder_admin());
drop policy if exists bew_wp_schreiben on bew_waermepumpe;
create policy bew_wp_schreiben on bew_waermepumpe for all to authenticated using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());

-- Werte aus den bisherigen FWS-Nachweisen (Aquark Silence 30, April 2026)
insert into bew_waermepumpe (hersteller, modell, heiz_a2_kw, lwa_a2_db, heiz_max_kw, lwa_erp_db, heiz_fluester_kw, lwa_fluester_db) values
  ('Aquark', 'Silence 30 MSRC 110', 10.5, 50, 7.2, 50, 3.6, 44),
  ('Aquark', 'Silence 30 MSRC 120', 12.2, 51, 6.9, 51, 4.3, 44),
  ('Aquark', 'Silence 30 MSRC 150', 15, 52, 8.4, 52, 5.3, 44),
  ('Aquark', 'Silence 30 MSRC 180', 18.2, 53, 10, 53, 6.2, 45),
  ('Aquark', 'Silence 30 MSRC 430-S', 42.5, 57, 24, 57, 15.2, 47)
on conflict (hersteller, modell) do nothing;

alter table bewilligung add column if not exists laerm jsonb not null default '{}';
