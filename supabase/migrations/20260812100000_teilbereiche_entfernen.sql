-- ============================================================================
-- Offertentool 2027 - "Teilbereiche moeglich" (mehrere identische, duplizier-
-- bare Bauteile pro Offerte) komplett entfernt. Jede Formel-Offerte hat ab
-- jetzt immer genau einen impliziten Bereich statt eines Arrays von
-- Teilflaechen. Ersetzt teilflaeche/teilflaeche_eingabefeld_wert/
-- teilflaeche_auswahl durch flache, direkt an offerte_id haengende Tabellen/
-- Spalten (gleiches Muster wie beim Tagessatz-Berechnungsmodell, das nie ein
-- Teilflaechen-Konzept hatte).
-- ============================================================================

-- Ersatz fuer teilflaeche.zugaenglichkeit_stufe: direkt auf offerte.
alter table offerte add column zugaenglichkeit_stufe integer not null default 2
  check (zugaenglichkeit_stufe between 1 and 4);

-- Ersatz fuer teilflaeche_eingabefeld_wert: direkt an offerte_id.
create table offerte_eingabefeld_wert (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  eingabefeld_id uuid not null references eingabefeld(id) on delete restrict,
  wert numeric not null,
  unique (offerte_id, eingabefeld_id)
);
alter table offerte_eingabefeld_wert enable row level security;
create policy offerte_eingabefeld_wert_voller_zugriff on offerte_eingabefeld_wert
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Ersatz fuer teilflaeche_auswahl: direkt an offerte_id. Anders als beim
-- fruehen, rueckgebauten Versuch (offerte_auswahl im Juli) gibt es diesmal
-- keine Teilflaeche mehr, die eine per-Teilflaeche-Auswahl noetig macht -
-- der damalige Rueckbau-Grund entfaellt.
create table offerte_auswahl (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  option_id uuid not null references auswahloption(id) on delete restrict,
  anzahl numeric not null default 1,
  unique (offerte_id, option_id)
);
alter table offerte_auswahl enable row level security;
create policy offerte_auswahl_voller_zugriff on offerte_auswahl
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Daten aus der jeweils ERSTEN Teilflaeche (nach reihenfolge) pro Offerte
-- uebernehmen - weitere Teilflaechen (falls je eine Offerte mehr als eine
-- hatte) gehen bewusst verloren, siehe Datensicherheits-Hinweis im Chat.
with erste_tf as (
  select distinct on (offerte_id) id, offerte_id
  from teilflaeche
  order by offerte_id, reihenfolge
)
update offerte o set zugaenglichkeit_stufe = t.zugaenglichkeit_stufe
from erste_tf e join teilflaeche t on t.id = e.id
where o.id = e.offerte_id;

with erste_tf as (
  select distinct on (offerte_id) id, offerte_id
  from teilflaeche
  order by offerte_id, reihenfolge
)
insert into offerte_eingabefeld_wert (offerte_id, eingabefeld_id, wert)
select e.offerte_id, w.eingabefeld_id, w.wert
from erste_tf e join teilflaeche_eingabefeld_wert w on w.teilflaeche_id = e.id
on conflict (offerte_id, eingabefeld_id) do nothing;

with erste_tf as (
  select distinct on (offerte_id) id, offerte_id
  from teilflaeche
  order by offerte_id, reihenfolge
)
insert into offerte_auswahl (offerte_id, option_id, anzahl)
select e.offerte_id, a.option_id, a.anzahl
from erste_tf e join teilflaeche_auswahl a on a.teilflaeche_id = e.id
on conflict (offerte_id, option_id) do nothing;

-- offerte_eigene_zeile: Bezug zur (jetzt einzigen) Teilflaeche ist danach nur
-- noch implizit ueber offerte_id - Zeilen, die zu einer ANDEREN als der
-- ersten Teilflaeche gehoerten, verlieren ihren teilflaeche_id-Bezug (die
-- Spalte selbst verschwindet gleich danach ohnehin).
with erste_tf as (
  select distinct on (offerte_id) id, offerte_id
  from teilflaeche
  order by offerte_id, reihenfolge
)
update offerte_eigene_zeile ez set teilflaeche_id = null
where teilflaeche_id is not null
  and teilflaeche_id not in (select id from erste_tf);

alter table offerte_eigene_zeile drop column teilflaeche_id;
alter table ressourcenzeile drop column teilflaechen_kombination;
alter table offertentyp drop column teilbereiche_moeglich;

drop table teilflaeche_auswahl;
drop table teilflaeche_eingabefeld_wert;
drop table teilflaeche;
