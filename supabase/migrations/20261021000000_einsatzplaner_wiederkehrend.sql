-- ============================================================================
-- Einsatzplaner: Wiederholung direkt am Eintrag (wie Google Kalender)
-- wdh = null: einmalig. Sonst Regel als JSON, der Eintrag selbst ist der erste Termin:
--   { "p": "w2",                     Vorlage (w1, w2, mn, ml, md, y, wt, custom)
--     "u": "w"|"m"|"y", "n": 2,      alle n Wochen / Monate / Jahre
--     "days": [2],                   Wochentage 0=So..6=Sa (bei Wochen)
--     "mm": "date"|"nth"|"last",     bei Monaten: am Datum / n-ter / letzter Wochentag
--     "ende": "nie"|"bis"|"anzahl", "bis": "2026-12-31", "anzahl": 10,
--     "fe": "skip"|"next"|"keep",    an Feiertagen auslassen / verschieben / eintragen
--     "aus": ["2026-11-10"] }        einzeln gelöschte oder verschobene Termine
-- Die Wiederholungen werden im Planer berechnet, nicht als Zeilen gespeichert.
-- (planer_serie wird nicht mehr benutzt.)
-- ============================================================================
alter table planer_einsatz add column if not exists wdh jsonb null;
create index if not exists planer_einsatz_wdh_idx on planer_einsatz ((wdh is not null)) where wdh is not null;
