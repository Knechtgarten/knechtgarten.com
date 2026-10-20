-- ============================================================================
-- Einsatzplaner: Kopieren von Auftraegen und Grund fuer «Start fix»
-- kopie_von       Original, von dem dieser Auftrag kopiert wurde (Detailfeld
--                 zeigt «Kopie von …» und bietet Notiz/Fotos/Dokumente an).
-- start_fix_grund Warum der Start fix ist, z. B. «mit Kunde fix abgemacht».
-- ============================================================================
alter table planer_einsatz add column if not exists kopie_von uuid null references planer_einsatz(id) on delete set null;
alter table planer_einsatz add column if not exists start_fix_grund text null;
