-- ============================================================================
-- Bewaesserungsplan als feste Sondertabelle (ersetzt die frei konfigurierbare
-- Tabelle der Kategorie Bewaesserung).
--
-- pflege_kategorie.sondertabelle = 'bewaesserung' -> beim Kunden erscheint statt
-- der normalen Tabelle der Bewaesserungsplan. Er ist nicht in den Pflegekategorien
-- umbaubar.
--
-- pflege_kunde_kategorie.bewaesserung = Liste der Ventile:
--   [{ rt: <Rohnertec-Ventil-id|null>, name, sensor, bem,
--      muster: [{ von:'hh:mm', bis:'hh:mm', tage:[0..6] (0 = Mo), gw:<% oder null>, zr:'26.5.–31.8.'|'' }] }]
--
-- pflege_kunde.rohnertec_id = Endkunde in Rohnertec (fuer den zentralen Abgleich).
-- ============================================================================
alter table pflege_kategorie add column sondertabelle text null check (sondertabelle in ('bewaesserung'));
update pflege_kategorie set sondertabelle = 'bewaesserung' where name = 'Bewässerung';

alter table pflege_kunde_kategorie add column bewaesserung jsonb not null default '[]'::jsonb;
alter table pflege_kunde_kategorie add column bewaesserung_stand timestamptz null;

alter table pflege_kunde add column rohnertec_id integer null unique;

-- bisherige frei konfigurierte Tabelle der Bewaesserung entfernen (Spalten fallen mit)
update pflege_kunde_kategorie kk set tabelle_zeilen = '[]'::jsonb
  from pflege_kategorie k where k.id = kk.kategorie_id and k.sondertabelle = 'bewaesserung';
delete from pflege_tabelle t using pflege_kategorie k where k.id = t.kategorie_id and k.sondertabelle = 'bewaesserung';
