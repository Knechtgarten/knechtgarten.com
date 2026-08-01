-- ============================================================================
-- Offertentool 2027 - Zentrale Einheiten-Tabelle statt Freitext an mehreren
-- Stellen (Artikel, Eingabefeld, Term, Sonderposition-Typ usw.). Verhindert
-- kuenftig Inkonsistenzen wie "m" vs. "Meter" - alle Auswahlfelder im Tool
-- lesen ab jetzt dieselbe Liste, die hier unter Einstellungen -> Rechenlogik
-- selbst erweitert/geaendert werden kann (kein Code-Update noetig fuer eine
-- neue Einheit). Die Kurzformen sind bewusst an SI_EINHEIT_KURZFORM in
-- einstellungen-live-v1.html angelehnt (bereits bestehende Normalisierung
-- fuer den KI-Schnellimport), damit beide Quellen dieselbe Schreibweise
-- verwenden.
-- ============================================================================

create table einheit (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,   -- z.B. "m", "Stk.", "Pauschale" - wird in Formularen/DB gespeichert
  name text null,              -- ausgeschriebene Form, z.B. "Laufmeter", "Tonne" - nur zur Anzeige
  reihenfolge integer not null default 0
);
alter table einheit enable row level security;
create policy einheit_voller_zugriff on einheit
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

insert into einheit (code, name, reihenfolge) values
  ('Stk.', 'Stück', 1),
  ('Sack', null, 2),
  ('m', 'Laufmeter', 3),
  ('cm', 'Zentimeter', 4),
  ('mm', 'Millimeter', 5),
  ('m²', 'Fläche', 6),
  ('m³', 'Volumen', 7),
  ('kg', null, 8),
  ('g', 'Gramm', 9),
  ('t', 'Tonne', 10),
  ('l', 'Liter', 11),
  ('Std.', 'Stunde', 12),
  ('km', null, 13),
  ('Pauschale', null, 14);

-- ----------------------------------------------------------------------------
-- Einmaliger Aufraeum-Durchlauf: bestehende, bisher frei getippte Einheiten
-- auf die neue kanonische Schreibweise vereinheitlichen (nur exakte,
-- bekannte Abweichungen - unbekannte Werte bleiben unveraendert stehen und
-- muessen von Hand nachgezogen werden).
-- ----------------------------------------------------------------------------
update eingabefeld set einheit = 'm' where einheit = 'Meter';

update term set einheit = 'Std.' where einheit = 'Std';

update artikel set einheit = 'Std.' where einheit = 'Stunde';
update artikel set einheit = 'Stk.' where einheit = 'Stk';
update artikel set einheit = 'm³' where einheit = 'm3';
update artikel set einheit = 'Sack' where einheit = 'sack';

update artikel set zusatzeinheit = 'l' where zusatzeinheit = 'Liter';
update artikel set zusatzeinheit = 'm³' where zusatzeinheit = 'm3';
