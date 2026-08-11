-- ============================================================================
-- Offertentool 2027 - Lieferwagenfahrzeit: Personalaufwand im Lieferwagen +
-- Fahrhaeufigkeit (aus/woechentlich/taeglich statt immer nur einmal pro
-- Offerte). Die Anzahl Arbeitstage wird in Tool A aus der Gesamtstundenzahl
-- Personal ueber die ganze Offerte berechnet (aufgerundet(Gesamtstunden /
-- Stunden pro Arbeitstag)) - hier nur die Stammdaten dafuer.
-- ============================================================================

alter table lieferwagen_konfiguration
  add column stunden_pro_arbeitstag numeric,
  add column vorarbeiter_artikel_id uuid null references artikel(id),
  add column gartenarbeiter_artikel_id uuid null references artikel(id);

-- Pro Offerte: fuer Lieferwagen/Vorarbeiter/Gartenarbeiter unabhaengig
-- waehlbar, wie oft die Fahrt (Hin+Rueck) tatsaechlich anfaellt:
-- 'aus' = kein Kosten (z.B. Sonderabmachung, Fahrt ist kostenlos)
-- 'woechentlich' = aufgerundet(Anzahl Arbeitstage / 5) Fahrten
-- 'taeglich' = Anzahl Arbeitstage Fahrten
alter table offerte
  add column lieferwagen_frequenz text not null default 'taeglich'
    check (lieferwagen_frequenz in ('aus','woechentlich','taeglich')),
  add column vorarbeiter_frequenz text not null default 'taeglich'
    check (vorarbeiter_frequenz in ('aus','woechentlich','taeglich')),
  add column gartenarbeiter_frequenz text not null default 'taeglich'
    check (gartenarbeiter_frequenz in ('aus','woechentlich','taeglich'));
