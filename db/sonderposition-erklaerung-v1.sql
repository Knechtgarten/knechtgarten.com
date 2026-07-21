-- ============================================================================
-- Offertentool 2027 - Sonderpositionen: eigene, editierbare Erklaerung statt
-- generischem Auto-Text ("Sonderposition mit Staffelung fuer X"). Passt das
-- Muster von Staffelgruppe/Zonengruppe an sonderposition_typ an, das dieses
-- Feld schon hatte.
-- ============================================================================
alter table staffelgruppe add column erklaerung text null;
alter table zonengruppe add column erklaerung text null;
