-- Eine Tabellenzeile kann mehreren Verweis-Optionen zugeordnet sein (je eine pro Gruppe,
-- z.B. Fundation und Verputzen). option_id bleibt als Kopie der ersten Zuordnung bestehen.
alter table offerte_tabelle_zeile add column if not exists option_ids uuid[] not null default '{}';
update offerte_tabelle_zeile set option_ids = array[option_id] where option_id is not null and option_ids = '{}';
