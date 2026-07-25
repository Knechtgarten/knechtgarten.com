-- ============================================================================
-- Offertentool 2027 - Kategorie bei JEDER Sonderposition fest hinterlegt und
-- in Einstellungen aenderbar, statt bei Staffelgruppe/Zonengruppe automatisch
-- vom ersten hinterlegten Artikel abgeleitet zu werden.
--
-- Vorher: Betonpumpe (Staffelgruppe) und PLZ-Zonen-Sonderpositionen haben
-- ihre Kategorie implizit vom jeweils ersten erfassten Artikel geerbt -
-- unsichtbar und nicht direkt aenderbar. Neu: eine Sonderposition hat genau
-- eine Kategorie, hier fest hinterlegt und in Einstellungen als Dropdown
-- sichtbar/aenderbar - eindeutige, einzige Quelle statt zwei moeglicherweise
-- widerspruechlichen (Artikel vs. Sonderposition).
-- ============================================================================

alter table staffelgruppe add column kategorie text null
  check (kategorie in ('personal','maschine','logistik','material'));
alter table zonengruppe add column kategorie text null
  check (kategorie in ('personal','maschine','logistik','material'));

update staffelgruppe set kategorie = 'logistik' where name = 'Betonpumpe';
