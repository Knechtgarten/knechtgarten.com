-- ============================================================================
-- Offertentool 2027 - Feld bei Kieswerken umbenennen: "MwSt-Zuschlag" war
-- falsch benannt, gemeint ist eine Marge (Prozent-Aufschlag auf Pauschale +
-- km-Preis). Die eigentliche MwSt kommt erst ganz am Schluss bei der
-- Totalisierung der Offerte dazu (separates Thema, noch zu klaeren) - hat
-- nichts mit dieser Spalte hier zu tun.
-- ============================================================================

alter table kieswerk_kies rename column mwst_satz_pct to marge_pct;
alter table kieswerk_beton rename column mwst_satz_pct to marge_pct;
