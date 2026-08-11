-- ============================================================================
-- Offertentool 2027 - Vorarbeiter (normal) und Vorarbeiter Poolbau sind ein
-- Entweder-Oder pro Offerte, nie beide gleichzeitig aktiv. Ersetzt die
-- bisherige zweite, unabhaengige Frequenz-Spalte durch einen gemeinsamen
-- Pool/Normal-Schalter (vorarbeiter_typ) - die Frequenz (aus/woechentlich/
-- taeglich) kommt weiterhin aus der bestehenden vorarbeiter_frequenz-Spalte.
-- ============================================================================

alter table offerte add column vorarbeiter_typ text not null default 'normal'
  check (vorarbeiter_typ in ('normal', 'pool'));

alter table offerte drop column if exists vorarbeiter_poolbau_frequenz;
