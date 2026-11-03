-- GAV Grüne Branche (Datei aus G:\Geteilte Ablagen\30_Intranet\Intranet Mitarbeiter, Stand 23.12.2020) ist im Bucket doku-dateien hochgeladen.
update doku_vorlage set datei_pfad = 'gav/2020-12-23-gav.pdf', stand = '2020-12-23' where schluessel = 'gav' and datei_pfad is null;
insert into doku_version (vorlage_id, stand, datei_pfad, erstellt_von)
select id, '2020-12-23', 'gav/2020-12-23-gav.pdf', null from doku_vorlage
where schluessel = 'gav' and not exists (select 1 from doku_version x where x.datei_pfad = 'gav/2020-12-23-gav.pdf');
