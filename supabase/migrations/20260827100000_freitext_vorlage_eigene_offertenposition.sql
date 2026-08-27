-- ============================================================================
-- "Eigene Offertenposition" (Stecknadel-Icon) neu auch fuer Freitext-
-- Positionen (option_freitext_vorlage): ohne Pin zaehlt eine Freitext-
-- Position in Tool A ganz normal zum Materialpaket/Logistikaufwand ihres
-- Arbeitsschritts (bzw. ihrer Option, falls diese gepinnt ist) - mit Pin
-- wird sie zu einer eigenen Zeile, deren Text (und Menge/Einheit/Preis) in
-- der Offerte frei editierbar ist. Gleiches Prinzip wie bei
-- ressourcenzeile.ist_eigene_offertenposition (siehe
-- 20260827090000_ressourcenzeile_eigene_offertenposition.sql), diesmal auf
-- der Freitext-Vorlage. Gilt ebenfalls nur fuer Material und Logistik.
-- ============================================================================

alter table option_freitext_vorlage add column ist_eigene_offertenposition boolean not null default false;
