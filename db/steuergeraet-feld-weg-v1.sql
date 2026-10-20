-- ============================================================================
-- Bewaesserung: Feld «Steuergeraet» entfaellt (das System waehlt man jetzt im
-- Umschalter des Bewaesserungsplans). Der Tag «Rohnertec» hing an der Auswahl
-- «Rohnertec» dieses Felds; er wird neu automatisch allen Kunden gegeben, die mit
-- Rohnertec verknuepft sind (pflege_kunde.rohnertec_id).
-- ============================================================================
alter table pflege_tag add column automatisch text null check (automatisch in ('rohnertec'));
update pflege_tag set automatisch = 'rohnertec' where name = 'Rohnertec';

-- Werte des Felds bei den Kunden entfernen, dann das Feld selbst
update pflege_kunde_kategorie kk set werte = kk.werte - f.id::text
  from pflege_feld f join pflege_kategorie k on k.id = f.kategorie_id
 where k.sondertabelle = 'bewaesserung' and f.name = 'Steuergerät' and kk.kategorie_id = k.id and kk.werte ? f.id::text;
delete from pflege_feld f using pflege_kategorie k
 where k.id = f.kategorie_id and k.sondertabelle = 'bewaesserung' and f.name = 'Steuergerät';
