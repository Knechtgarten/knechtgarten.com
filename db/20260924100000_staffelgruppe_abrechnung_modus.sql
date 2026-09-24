-- Staffelgruppe (Sonderposition mit Staffelung): bisher wurde nach dem
-- Finden der passenden Stufe IMMER eine fixe Pauschale verrechnet (Menge=1,
-- Betrag=Stufenpreis) - unabhaengig davon, wie gross die berechnete Menge
-- (z.B. Flaeche) tatsaechlich war. Das passt fuer "1 Teil aus einer Palette
-- waehlen" (z.B. Betonpumpe, Filter, LED-Band in fixer Laenge), aber nicht
-- fuer Preise, die selbst pro Einheit gelten und nur der SATZ gestaffelt
-- (mengenrabattiert) ist (z.B. Terrassenholz/Rollrasen: CHF/m² sinkt mit der
-- Flaeche, verrechnet wird aber Flaeche x Satz, nicht 1x Satz).
--
-- Neues Feld legt das pro Staffelgruppe fest. Default 'pauschale' erhaelt
-- das bisherige Verhalten fuer alle bestehenden Staffelgruppen (Betonpumpe
-- & Co.) unveraendert.
alter table staffelgruppe add column abrechnung_modus text not null default 'pauschale'
  check (abrechnung_modus in ('pauschale', 'pro_einheit'));

-- Bekannte Faelle mit echtem Preis-pro-Einheit (Absprache 2026-09-24):
-- Holz Douglasie, Holz Thermo Kiefer, Rollrasen normal, Rollrasen spezial.
update staffelgruppe set abrechnung_modus = 'pro_einheit'
where name in ('Neue Staffelung 10', 'Neue Staffelung 11', 'rollrasen_normal_staffel', 'rollrasen_spezial_staffel');
