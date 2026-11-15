-- KI-Offerte: Herkunft des Preises pro Zeile (Icon + Jahr im Blatt)
alter table public.offerte_eigene_zeile
  add column if not exists ki_quelle text,        -- artikel | offerte | easybill | vorgabe | geschaetzt
  add column if not exists ki_quelle_nr text,     -- Artikelnr., Offertnummer oder Easybill-Angebotsnummer
  add column if not exists ki_quelle_datum date,  -- Datum der Quelle (alte Offerte / Angebot)
  add column if not exists ki_quelle_info text;   -- kurz: Kunde / Bezeichnung in der Quelle
update public.offerte_eigene_zeile set ki_quelle = 'geschaetzt' where ki_geschaetzt and ki_quelle is null;
select count(*) from public.offerte_eigene_zeile where ki_quelle is not null;
