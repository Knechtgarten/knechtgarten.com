-- ============================================================================
-- Offertentool 2027 - sync_offertentool/sync_webtool sind reine "Reserve"-
-- Flags ohne jede Funktion im Code (nirgends ausgewertet, ausser in der
-- eigenen Anzeige/Bearbeitung im Artikelstamm). sync_offertentool stand
-- bisher per DB-Default auf true, wodurch jeder neu angelegte Artikel
-- (z.B. via Schnellimport, der das Feld gar nicht mitschickt) automatisch
-- angehakt wurde, obwohl niemand weiss, wofuer das Haekchen gut sein soll.
-- Default auf false umgestellt + rueckwirkend bei allen Artikeln entfernt.
-- sync_webtool war schon immer false per Default, wird hier nur zur
-- Sicherheit ebenfalls rueckwirkend bereinigt.
-- ============================================================================

alter table artikel alter column sync_offertentool set default false;

update artikel set sync_offertentool = false, sync_webtool = false;
