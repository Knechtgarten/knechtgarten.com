-- ============================================================================
-- Einsatzplaner Etappe 4: Pflege-Vorschlaege als «Perlenkette» im Planer
--
-- Nur neue Felder, nichts Bestehendes wird veraendert:
--   pflege_arbeit.dauer_min          Standard-Dauer einer Arbeit (Minuten, Standard 60)
--   pflege_kunde_arbeit.dauer_min    Uebersteuerung pro Kunde (leer = Standard)
--   pflege_kunde.wunsch_wochentage   1 = Montag … 5 = Freitag (leer = egal)
--   planer_einsatz.pflege_*          Einsatz stammt aus einem Pflege-Vorschlag
--                                    (Kunde/Kategorie + Jahr + KW). Solange es diesen
--                                    Einsatz gibt, zeigt der Planer die Perle nicht mehr.
-- Eingabemasken im Pflege-Tool fuer Dauer und Wunsch-Wochentage folgen separat.
-- ============================================================================

alter table pflege_arbeit add column if not exists dauer_min integer not null default 60 check (dauer_min between 5 and 1440);
alter table pflege_kunde_arbeit add column if not exists dauer_min integer null check (dauer_min between 5 and 1440);
alter table pflege_kunde add column if not exists wunsch_wochentage integer[] not null default '{}'
  check (wunsch_wochentage <@ '{1,2,3,4,5,6,7}'::integer[]);

alter table planer_einsatz add column if not exists pflege_kunde_kategorie_id uuid null references pflege_kunde_kategorie(id) on delete set null;
alter table planer_einsatz add column if not exists pflege_jahr integer null;
alter table planer_einsatz add column if not exists pflege_kw integer null check (pflege_kw between 1 and 53);
create index if not exists planer_einsatz_pflege_idx on planer_einsatz (pflege_kunde_kategorie_id, pflege_jahr, pflege_kw);
