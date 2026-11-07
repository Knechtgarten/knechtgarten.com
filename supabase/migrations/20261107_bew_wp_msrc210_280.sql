-- Aquark Silence 30 MSRC 210 und 280-S (Katalog 2026, Seite «Technische Details» 3).
-- Heizleistung: A2 = L27/W27 Turbo, max = L15/W26 Turbo, Flüster = L15/W26 Silent.
-- Schallleistung = Schalldruck bei 10 m + 28 dB (wie bei den übrigen Modellen): oberer Wert = Normalbetrieb, unterer = Flüstermodus.
-- MSRC 210: 54 dB(A) laut FWS-Übersicht (26,8 + 28 = 54,8), Flüster 17,6 + 28 = 46. MSRC 280-S: 28,3 + 28 = 56, Flüster 17,9 + 28 = 46.
insert into public.bew_waermepumpe (hersteller, modell, heiz_a2_kw, lwa_a2_db, heiz_max_kw, lwa_erp_db, heiz_fluester_kw, lwa_fluester_db, aktiv, vol_min, vol_max, datenblatt_pfad, datenblatt_seite)
select * from (values
  ('Aquark', 'Silence 30 MSRC 210',   20.6, 54, 14.4, 54,  7.2, 46, true, 40, 75, 'aquark-katalog-2026-kap15.pdf', 3),
  ('Aquark', 'Silence 30 MSRC 280-S', 28.7, 56, 20.0, 56, 10.0, 46, true, 60, 90, 'aquark-katalog-2026-kap15.pdf', 3)
) v(hersteller, modell, heiz_a2_kw, lwa_a2_db, heiz_max_kw, lwa_erp_db, heiz_fluester_kw, lwa_fluester_db, aktiv, vol_min, vol_max, datenblatt_pfad, datenblatt_seite)
where not exists (select 1 from public.bew_waermepumpe w where w.modell = v.modell);
