-- ============================================================================
-- Offertentool 2027 - Optionale Mengen-Anzeige direkt beim Teilschritt-Titel
-- in Tool A (z.B. "Hinterfuellung - 12.5 m3"), damit der Mitarbeiter beim
-- Konfigurieren sieht, wie viel Menge in diesem Abschnitt anfaellt. Rein
-- optional - nur wenn in Tool B ueber den neuen Button explizit ein Wert
-- (Eingabefeld ODER Formel-Wert) zugeordnet wurde, erscheint die Anzeige.
-- ============================================================================

alter table teilschritt add column anzeige_eingabefeld_id uuid null references eingabefeld(id) on delete set null;
alter table teilschritt add column anzeige_term_id uuid null references term(id) on delete set null;
alter table teilschritt add constraint teilschritt_hoechstens_eine_anzeige check (
  (case when anzeige_eingabefeld_id is not null then 1 else 0 end
   + case when anzeige_term_id is not null then 1 else 0 end) <= 1
);
