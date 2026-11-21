-- Bewässerung (Offertentyp der Offerte 2026-010102): Formel-Eingabe («Wert als Formel berechnen») überall aus (Stefan 2026-11-21).
-- Die zweite Zeile unter dem Zahlenfeld wirkte in den schmalen Tabellen wie zwei Felder übereinander.
update eingabefeld_tabelle_spalte s set flaechenformel_moeglich = false
from eingabefeld ef
where s.eingabefeld_id = ef.id and s.flaechenformel_moeglich
  and ef.offertentyp_id = (select offertentyp_id from offerte where offertnummer = '2026-010102' limit 1);
update eingabefeld set flaechenformel_moeglich = false
where flaechenformel_moeglich and offertentyp_id = (select offertentyp_id from offerte where offertnummer = '2026-010102' limit 1);
select (select name from offertentyp where id = (select offertentyp_id from offerte where offertnummer = '2026-010102' limit 1)) typ,
  (select count(*) from eingabefeld_tabelle_spalte s join eingabefeld ef on ef.id = s.eingabefeld_id
    where s.flaechenformel_moeglich and ef.offertentyp_id = (select offertentyp_id from offerte where offertnummer = '2026-010102' limit 1)) noch_mit_formel;
