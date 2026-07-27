-- ============================================================================
-- Offertentool 2027 - Erlaubte Kategorien pro Lieferant, direkt in den
-- Einstellungen konfigurierbar statt jedes Mal im Abgleich-Fenster manuell
-- auszuwaehlen.
--
-- Ist genau EINE Kategorie angehakt, gilt sie als fest vorgegeben (keine
-- Auswahl mehr noetig/moeglich im Abgleich-Fenster). Sind mehrere angehakt,
-- zeigt das Abgleich-Fenster nur noch diese zur Auswahl (statt immer alle
-- vier) - reduziert das Risiko, aus Versehen die falsche Kategorie zu
-- waehlen. Sind keine angehakt (Standardfall bei bestehenden Lieferanten),
-- bleibt das Verhalten unveraendert: alle vier stehen zur Auswahl.
--
-- Greift nur als Standard/Filter fuer Quellen ohne eigene Kategorie-Angabe
-- (z.B. Google Sheet, einfache PDFs) - liefert eine Quelle die Kategorie
-- schon pro Artikel selbst mit (z.B. die Daepp-Gesamtpreisliste), hat das
-- weiterhin Vorrang (siehe kategorie-Feld in den PDF-Parsern).
-- ============================================================================

alter table lieferant_datenabgleich add column kategorie_material boolean not null default false;
alter table lieferant_datenabgleich add column kategorie_personal boolean not null default false;
alter table lieferant_datenabgleich add column kategorie_maschine boolean not null default false;
alter table lieferant_datenabgleich add column kategorie_logistik boolean not null default false;
