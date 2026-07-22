-- ============================================================================
-- Offertentool 2027 - Kunde: Easybill-aehnliche Adress-/Kontaktfelder
--
-- Erweitert die bisher sehr schmale kunde-Tabelle (id, name, adresse, plz,
-- easybill_id) um die Felder aus Easybills "Kontakt bearbeiten"-Fenster, damit
-- ein Kunde im Offertentool genauso vollstaendig erfasst werden kann.
--
-- Strasse/Ort/Land werden als echte Spalten gefuehrt (sortierbar/durchsuchbar
-- in der Kunden-Uebersicht, siehe Tool D). Telefon/Fax/Mobil/E-Mails sowie die
-- optionale Lieferanschrift leben als flexible jsonb-Felder, da sie in der
-- Uebersicht nicht als eigene Spalte gebraucht werden.
--
-- Das bestehende Feld "name" bleibt die massgebliche Anzeige-/Suchbezeichnung
-- (wird von Tool A/A2 fuer die Kunde-Suche verwendet) und wird beim Speichern
-- des neuen Kunde-Formulars automatisch aus Firma bzw. Vorname+Nachname
-- nachgefuehrt - keine Aenderung an der bestehenden Suche noetig.
-- ============================================================================

alter table kunde add column kundennummer text null;
alter table kunde add column firma text null;
alter table kunde add column anrede text null;
alter table kunde add column vorname text null;
alter table kunde add column nachname text null;
alter table kunde add column zusatz1 text null;
alter table kunde add column zusatz2 text null;
alter table kunde add column strasse text null;
alter table kunde add column ort text null;
alter table kunde add column land text null default 'Schweiz';
alter table kunde add column kontaktdaten jsonb null; -- {telefon1, telefon2, fax, mobil, emails: []}
alter table kunde add column lieferanschrift jsonb null; -- {strasse, plz, ort, bundesland, land}

-- Sicherheits-Fix: Ein Kunde mit noch bestehenden Offerten darf nicht geloescht
-- werden (bisher CASCADE - haette alle seine Offerten stillschweigend
-- mitgeloescht). Jetzt RESTRICT - Loeschen schlaegt fehl, bis alle Offerten
-- dieses Kunden zuerst einzeln geloescht wurden (siehe Tool D Loeschen-Guard).
-- Name des bestehenden FK-Constraints dynamisch ermitteln statt zu raten.
do $$
declare
  fk_name text;
begin
  select conname into fk_name
  from pg_constraint
  where conrelid = 'offerte'::regclass
    and confrelid = 'kunde'::regclass
    and contype = 'f';
  execute format('alter table offerte drop constraint %I', fk_name);
  execute 'alter table offerte add constraint offerte_kunde_id_fkey foreign key (kunde_id) references kunde(id) on delete restrict';
end $$;
