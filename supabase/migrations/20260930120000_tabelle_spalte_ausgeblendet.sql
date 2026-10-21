-- Rechenspalten von Eingabe-Tabellen koennen im Konfigurator ausgeblendet werden:
-- die Spalte rechnet weiter im Hintergrund (Summen, Formeln), erscheint aber nicht in der Tabelle.
alter table eingabefeld_tabelle_spalte add column if not exists ausgeblendet boolean not null default false;
