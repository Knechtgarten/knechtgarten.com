-- ============================================================================
-- Offertentool 2027 - Zwei neue Adresslisten fuer Distanz-Systemwerte:
-- "Fahrt Baustelle zu naechstem Kieswerk" und "...zu naechster Deponie".
--
-- Bewusst EIGENE Tabellen statt Wiederverwendung von kieswerk_kies/
-- kieswerk_beton (die fuer die Kies-/Beton-Transport-Sonderposition
-- Pauschale/km-Preis/Marge/Mindestmenge mitfuehren): der Nutzer moechte
-- fuer diese Distanzberechnung gezielt eine eigene Auswahl treffen koennen
-- (nicht zwingend alle Kies-/Beton-Kieswerke, ggf. zusaetzliche). Nur
-- Name+Adresse noetig, da hier nur die naechstgelegene Distanz zaehlt,
-- keine Preisfindung.
--
-- Als Starthilfe werden die bereits vorhandenen Kieswerke (aus Kies- UND
-- Beton-Transport, dedupliziert nach Name+Adresse) einmalig uebernommen -
-- der Nutzer kann sie danach frei anpassen/loeschen/ergaenzen.
-- ============================================================================

create table kieswerk_distanz (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null,
  reihenfolge integer not null default 0
);
alter table kieswerk_distanz enable row level security;
create policy kieswerk_distanz_voller_zugriff on kieswerk_distanz
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

create table deponie_distanz (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null,
  reihenfolge integer not null default 0
);
alter table deponie_distanz enable row level security;
create policy deponie_distanz_voller_zugriff on deponie_distanz
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

insert into kieswerk_distanz (name, adresse, reihenfolge)
select name, adresse, row_number() over (order by name)
from (
  select distinct name, adresse from kieswerk_kies
  union
  select distinct name, adresse from kieswerk_beton
) t;
