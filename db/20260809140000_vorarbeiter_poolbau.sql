-- ============================================================================
-- Offertentool 2027 - Lieferwagenfahrzeit-Personalaufwand: zweiter
-- Vorarbeiter-Slot "Vorarbeiter Poolbau" neben dem bestehenden "Vorarbeiter"
-- (normal) - eigener Stundenansatz-Artikel + eigene Aus/Woechentlich/
-- Taeglich-Frequenz pro Offerte, unabhaengig von den anderen Posten.
-- ============================================================================

alter table lieferwagen_konfiguration
  add column vorarbeiter_poolbau_artikel_id uuid null references artikel(id);

alter table offerte
  add column vorarbeiter_poolbau_frequenz text not null default 'taeglich'
    check (vorarbeiter_poolbau_frequenz in ('aus','woechentlich','taeglich'));
