-- Datenblätter des Herstellers (Aquark, PDF in app/datenblaetter/) pro Wärmepumpe; Pfad mit «/» = Originaldatei der Website.
-- MSRC 280-S hat kein eigenes Datenblatt: bleibt bei der Katalogseite (Bucket bew-unterlagen, Seite 3).
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-110.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 110';
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-120.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 120';
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-150.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 150';
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-180.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 180';
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-210.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 210';
update public.bew_waermepumpe set datenblatt_pfad = '/datenblaetter/aquark-msrc-430-s.pdf', datenblatt_seite = null where modell = 'Silence 30 MSRC 430-S';
-- Silence MPXC 280-S (Art. 155004, R32, 400 V): Schallleistung = Schalldruck 10 m + 28 dB → 28,4 → 56, Flüster 18,0 → 46
insert into public.bew_waermepumpe (hersteller, modell, heiz_a2_kw, lwa_a2_db, heiz_max_kw, lwa_erp_db, heiz_fluester_kw, lwa_fluester_db, aktiv, vol_min, vol_max, datenblatt_pfad)
select 'Aquark', 'Silence MPXC 280-S', 28.0, 56, 19.5, 56, 9.8, 46, true, 60, 90, '/datenblaetter/aquark-mpxc-280-s.pdf'
where not exists (select 1 from public.bew_waermepumpe where modell = 'Silence MPXC 280-S');
