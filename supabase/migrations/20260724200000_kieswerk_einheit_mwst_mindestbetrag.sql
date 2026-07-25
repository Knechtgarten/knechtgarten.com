-- ============================================================================
-- Offertentool 2027 - Sonderpositionen: Einheit konfigurierbar, Kieswerke
-- bekommen MwSt-Zuschlag und Mindestverrechnungsbetrag.
--
-- Einheit: bei Kies-/Beton-Transport (sonderposition_typ) gibt es keinen
-- Artikel, von dem die Einheit (wie sonst ueblich) abgeleitet werden koennte -
-- deshalb hier frei eintippbar (z.B. "Pauschale", "Fahrt", "m3").
--
-- Pro Kieswerk zusaetzlich: MwSt-Zuschlag in % (Pauschale/km-Preis sind
-- Netto-Preise) und ein Mindestverrechnungsbetrag (falls Pauschale+Distanz
-- unter diesem Betrag liegen wuerde, gilt der Mindestbetrag).
-- ============================================================================

alter table sonderposition_typ add column einheit text null default 'Pauschale';
update sonderposition_typ set einheit = 'Pauschale' where name in ('Kies-Transport', 'Beton-Transport');

alter table kieswerk_kies add column mwst_satz_pct numeric not null default 0;
alter table kieswerk_kies add column mindestbetrag numeric not null default 0;
alter table kieswerk_beton add column mwst_satz_pct numeric not null default 0;
alter table kieswerk_beton add column mindestbetrag numeric not null default 0;
