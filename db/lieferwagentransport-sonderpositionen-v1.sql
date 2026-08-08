-- ============================================================================
-- Offertentool 2027 - Drei neue Sonderpositions-Typen fuer eigene
-- Lieferwagenfahrten (nicht zu verwechseln mit Kies-/Beton-Transport, wo das
-- KIESWERK anliefert): "Lieferwagentransport Kieswerk/Betonwerk" (nutzt die
-- bereits bestehenden Adresslisten kieswerk_kies/kieswerk_beton),
-- "Lieferwagentransport Deponie" (nutzt die bestehende deponie_distanz-Liste)
-- und "Lieferwagentransport Magazin" (eigene, neue Adressliste).
--
-- Anders als Kies-/Beton-Transport gibt es hier KEINE Pauschale/km-Preis pro
-- Adresse - stattdessen einen zentralen Artikel ("Lieferwagen Std"), dessen
-- Preis mit der einfachen Fahrzeit (Std, naechstgelegene Adresse -> Kunde)
-- multipliziert wird. So reicht eine Preisaenderung an EINEM Artikel, um alle
-- Lieferwagenfahrten neu zu bepreisen.
--
-- hat_eigene_berechnung ersetzt den bisherigen hart einprogrammierten
-- Namensvergleich in Tool B (sonderposition_typ.name === 'Kies-Transport' ...)
-- - damit werden auch die drei neuen Typen automatisch korrekt behandelt
-- (eigene Menge-Formel statt Artikel-Feld), ohne dass fuer jeden neuen Typ
-- wieder der Code angepasst werden muss.
-- ============================================================================

alter table sonderposition_typ add column hat_eigene_berechnung boolean not null default false;
update sonderposition_typ set hat_eigene_berechnung = true where name in ('Kies-Transport', 'Beton-Transport');

alter table sonderposition_typ add column lieferwagen_std_artikel_id uuid null references artikel(id) on delete restrict;

create table magazin_adressen (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null default '',
  reihenfolge int not null default 0,
  geprueft_ok boolean null,
  geprueft_fehler text null,
  erstellt_am timestamptz not null default now()
);
alter table magazin_adressen enable row level security;
create policy magazin_adressen_lesen on magazin_adressen for select using (ist_eingeloggter_benutzer());
create policy magazin_adressen_admin_schreibt on magazin_adressen for all using (ist_admin()) with check (ist_admin());

insert into sonderposition_typ (name, erklaerung, kategorie, einheit, hat_eigene_berechnung) values
  ('Lieferwagentransport Kieswerk/Betonwerk', 'Eigener Lieferwagen holt Kies/Beton - Fahrzeit (einfache Strecke, naechstgelegenes Kieswerk/Betonwerk aus kieswerk_kies/kieswerk_beton) x Preis des hinterlegten Lieferwagen-Std-Artikels.', 'logistik', 'Fahrt', true),
  ('Lieferwagentransport Deponie', 'Eigener Lieferwagen bringt Material zur Deponie - Fahrzeit (einfache Strecke, naechstgelegene Adresse aus deponie_distanz) x Preis des hinterlegten Lieferwagen-Std-Artikels.', 'logistik', 'Fahrt', true),
  ('Lieferwagentransport Magazin', 'Eigener Lieferwagen holt Material im eigenen Magazin/Lager - Fahrzeit (einfache Strecke, naechstgelegene Adresse aus magazin_adressen) x Preis des hinterlegten Lieferwagen-Std-Artikels.', 'logistik', 'Fahrt', true);
