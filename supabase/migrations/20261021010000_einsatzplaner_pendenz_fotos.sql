-- ============================================================================
-- Einsatzplaner: Fotos zu Pendenzen (Handy: Pendenz erfassen, Foto dazu)
-- planer_datei gehoert jetzt zu genau einem: Einsatz, Magazin-Arbeit oder Pendenz.
-- ============================================================================
alter table planer_datei add column if not exists pendenz_id uuid null references planer_pendenz(id) on delete cascade;
alter table planer_datei drop constraint if exists planer_datei_ziel;
alter table planer_datei add constraint planer_datei_ziel check (num_nonnulls(einsatz_id, magazin_id, pendenz_id) = 1);
create index if not exists planer_datei_pendenz_idx on planer_datei (pendenz_id);
create policy planer_datei_pendenz on planer_datei for all
  using (pendenz_id is not null and ist_eingeloggter_benutzer())
  with check (pendenz_id is not null and ist_eingeloggter_benutzer());
