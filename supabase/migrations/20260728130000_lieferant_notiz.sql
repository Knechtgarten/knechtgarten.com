-- ============================================================================
-- Offertentool 2027 - Freies Notizfeld pro Lieferant im Details-Fenster,
-- z.B. fuer Hinweise zur Erneuerung der Preisliste oder ob dieser Lieferant
-- (nicht) mit Easybill abgeglichen wird - reiner Freitext, keine Logik daran
-- gekoppelt.
-- ============================================================================

alter table lieferant_datenabgleich add column notiz text;
