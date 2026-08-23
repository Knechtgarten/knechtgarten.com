-- ============================================================================
-- "Eigene Offertenposition" (Option bearbeiten, Tool B): Material einer so
-- markierten Option wird nicht mehr ins Materialpaket ihres Arbeitsschritts
-- gezaehlt, sondern in Tool A als eigene Zeile "{Arbeitsschritt} – {Option}"
-- ausgewiesen. Personal-/Maschinen-/Logistikaufwand bleiben unveraendert im
-- jeweiligen Paket zusammengezaehlt - das Haeckchen wirkt sich ausschliesslich
-- auf den Materialaufwand aus.
-- ============================================================================

alter table auswahloption add column ist_eigene_offertenposition boolean not null default false;
