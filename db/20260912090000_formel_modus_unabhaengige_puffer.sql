-- ============================================================================
-- Formeltool (Baukasten) und Freie Formel (Text) muessen unabhaengig
-- voneinander bestehen bleiben - bisher wurde beim Speichern nur die AKTIVE
-- Formel abgelegt (menge_ausdruck bzw. ausdruck), die jeweils andere Seite
-- ging beim naechsten Oeffnen verloren bzw. wurde heuristisch aus derselben
-- gespeicherten Formel zurueckgerechnet (flattenMengenAusdruck). Das fuehrte
-- dazu, dass z.B. eine in "Freie Formel" eingegebene Formel wie "8/2" beim
-- Wiederoeffnen faelschlicherweise im Formeltool auftauchte, weil sie
-- zufaellig dort auch darstellbar war - obwohl der Nutzer sie nie im
-- Formeltool erfasst hat. Nutzer-Entscheid: beide Formen muessen jederzeit
-- unabhaengig editierbar bleiben, der beim Speichern gerade aktive Reiter
-- ist fuer die Berechnung massgeblich.
--
-- *_modus haelt fest, welcher Reiter beim letzten Speichern aktiv war (und
-- damit fuer die Berechnung massgeblich ist). *_text ist der rohe Freie-
-- Formel-Text, unabhaengig davon ob dieser Reiter gerade aktiv ist.
-- *_baukasten_ausdruck ist der vom Formeltool selbst gebaute Ausdruck,
-- ebenfalls unabhaengig von der Aktivitaet. Die bestehende Spalte
-- menge_ausdruck/ausdruck bleibt unveraendert die fuer eval_ausdruck()
-- massgebliche, AKTIVE Formel - sie wird bei jedem Speichern weiterhin aus
-- dem gerade aktiven Reiter befuellt.
--
-- Zeilen von VOR dieser Migration haben *_modus/*_text/*_baukasten_ausdruck
-- leer - der Frontend-Code (tool-b-live-v1.html, formelStateAusZeile())
-- interpretiert das weiterhin per Heuristik wie bisher, bis einmal neu
-- gespeichert wird.
-- ============================================================================

alter table ressourcenzeile
  add column menge_formel_modus text not null default 'baukasten' check (menge_formel_modus in ('baukasten', 'text')),
  add column menge_formel_text text null,
  add column menge_formel_baukasten_ausdruck jsonb null;

alter table term
  add column formel_modus text not null default 'baukasten' check (formel_modus in ('baukasten', 'text')),
  add column formel_text text null,
  add column formel_baukasten_ausdruck jsonb null;

alter table eingabefeld_tabelle_spalte
  add column formel_modus text not null default 'baukasten' check (formel_modus in ('baukasten', 'text')),
  add column formel_text text null,
  add column formel_baukasten_ausdruck jsonb null;
