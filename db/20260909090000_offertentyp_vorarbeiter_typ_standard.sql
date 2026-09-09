-- ============================================================================
-- Startwert des Vorarbeiter-Pool/Normal-Reglers pro Offertentyp (Vorlage) -
-- bisher startete jede neue Offerte hart bei "normal", auch bei einer reinen
-- Pool-Vorlage. Wird jetzt beim Anlegen einer neuen Offerte als Vorschlag
-- uebernommen (siehe starteNeueOfferte() in tool-a-live-v1.html), bleibt in
-- der Offerte selbst weiterhin frei umschaltbar.
-- ============================================================================

alter table offertentyp add column vorarbeiter_typ_standard text not null default 'normal'
  check (vorarbeiter_typ_standard in ('normal', 'pool'));
