-- Easybill-Abgleich (nur lesend) zusätzlich tagsüber: 7, 12 und 17 Uhr Schweizer Winterzeit (06/11/16 UTC), dazu wie bisher nachts 01 UTC.
-- Ein Lauf dauert rund 6 Sekunden und vergleicht jedes Mal den ganzen Stand (fällt einer aus, holt der nächste alles nach).
select cron.alter_job(job_id := (select jobid from cron.job where jobname = 'easybill-abgleich-nacht'), schedule := '0 1,6,11,16 * * *');
