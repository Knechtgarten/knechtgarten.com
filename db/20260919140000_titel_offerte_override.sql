-- Alternativer, frei aenderbarer (mehrzeiliger) Titel fuer die Offerten-
-- Ausgabe, getrennt vom internen/Konfigurator-Namen - null = weiterhin der
-- normale Name/die normale Zusammensetzung. Siehe Tool B: kleines T-Icon
-- neben dem Arbeitsschritt-Namen bzw. neben "Eigene Offertenposition".
alter table arbeitsschritt add column titel_offerte text null;
alter table auswahloption add column eigene_position_titel text null;
