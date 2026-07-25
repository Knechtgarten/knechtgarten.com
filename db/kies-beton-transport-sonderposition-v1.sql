-- ============================================================================
-- Offertentool 2027 - Kies-Transport/Beton-Transport als Sonderpositions-Typen
-- + Kieswerk-Auswahl pro Offerte.
--
-- Die zwei neuen sonderposition_typ-Eintraege tauchen automatisch im
-- bestehenden Sonderposition-Picker in Tool B auf (kein Code dort noetig).
-- Die eigentliche Berechnung (Kieswerk waehlen, Distanz per Google Distance
-- Matrix, Pauschale + km-Preis) passiert in Tool A - dafuer muss pro
-- gewaehlter Option (teilflaeche_auswahl) festgehalten werden, welches
-- Kieswerk der Mitarbeiter gewaehlt hat. Vorerst nur fuer Formel-Offerten
-- (Tool A) - Sonderpositionen werden bei Tagessatz-Offerten (Tool A2) aktuell
-- noch nicht berechnet, das ist eine bestehende, separate Pendenz.
-- ============================================================================

insert into sonderposition_typ (name, erklaerung) values
  ('Kies-Transport', 'Pauschale + Kilometerpreis ueber ein vom Mitarbeiter pro Offerte gewaehltes Kieswerk (Tabelle kieswerk_kies). Distanz Kieswerk -> Kunde per Google Distance Matrix.'),
  ('Beton-Transport', 'Pauschale + Kilometerpreis ueber ein vom Mitarbeiter pro Offerte gewaehltes Kieswerk (Tabelle kieswerk_beton). Distanz Kieswerk -> Kunde per Google Distance Matrix.');

alter table teilflaeche_auswahl add column kieswerk_kies_id uuid null references kieswerk_kies(id) on delete restrict;
alter table teilflaeche_auswahl add column kieswerk_beton_id uuid null references kieswerk_beton(id) on delete restrict;
alter table teilflaeche_auswahl add constraint teilflaeche_auswahl_hoechstens_ein_kieswerk check (
  (case when kieswerk_kies_id is not null then 1 else 0 end
   + case when kieswerk_beton_id is not null then 1 else 0 end) <= 1
);
