-- ============================================================================
-- Offertentool 2027 - Easybill-Verknuepfung + Adress-/Kontaktfelder fuer
-- Lieferanten, analog zum bestehenden Muster bei "kunde" (siehe
-- 20260721150000_kunde_easybill_verknuepfung.sql und
-- 20260721160000_kunde_easybill_felder.sql). Ermoeglicht das Importieren
-- eines Lieferanten direkt aus Easybill (read-only, gleiches Prinzip wie
-- bei der Kunden-Uebernahme).
-- ============================================================================

alter table lieferant add column easybill_id bigint null unique;
alter table lieferant add column lieferantennummer text null;
alter table lieferant add column firma text null;
alter table lieferant add column anrede text null;
alter table lieferant add column vorname text null;
alter table lieferant add column nachname text null;
alter table lieferant add column zusatz1 text null;
alter table lieferant add column zusatz2 text null;
alter table lieferant add column strasse text null;
alter table lieferant add column plz text null;
alter table lieferant add column ort text null;
alter table lieferant add column land text null default 'Schweiz';
alter table lieferant add column kontaktdaten jsonb null; -- {telefon1, telefon2, fax, mobil, emails: []}
