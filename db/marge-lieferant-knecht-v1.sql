-- ============================================================================
-- Offertentool 2027 - Marge Lieferant/Marge Knecht nur noch berechnet, nicht
-- mehr manuell eintragbar (Nutzer-Entscheidung 2026-07-21).
-- marge_aktuell_pct war bisher ein freies Eingabefeld - wird jetzt im
-- Artikel-Modal live aus EP/VP Lieferant, Wechselkurs, Zoll/Fracht-% und
-- Sonderzuschlag-% (beide vom Lieferanten, Basis EP) berechnet und nirgends
-- mehr gespeichert. Marge Knecht (neu, ebenfalls nur berechnet) vergleicht
-- denselben Einstandspreis mit dem VP Knecht (manuell oder aus der
-- Minimum-Marge des Lieferanten vorgeschlagen).
-- ============================================================================
alter table artikel drop column if exists marge_aktuell_pct;

-- Mitarbeiter duerfen die Lieferanten-Datenabgleich-Stammdaten (Zoll/
-- Sonderzuschlag/Minimum-Marge) jetzt LESEN (fuer die Margen-Berechnung im
-- Artikel-Modal noetig, siehe [[offertentool-architektur]]) - Schreiben
-- bleibt admin-only.
drop policy if exists lieferant_datenabgleich_admin on lieferant_datenabgleich;
create policy lieferant_datenabgleich_lesen on lieferant_datenabgleich for select using (ist_eingeloggter_benutzer());
create policy lieferant_datenabgleich_admin_schreibt on lieferant_datenabgleich for all using (ist_admin()) with check (ist_admin());
