-- ============================================================================
-- Offertentool 2027 - Optionen/Kieswerk-Wahl von "pro Teilflaeche" zu
-- "pro Offerte" verschoben.
--
-- Nutzer-Entscheid: Ein Bauteil (die ganze Offerte) wird immer einheitlich
-- behandelt - gleicher Bagger, gleiche Fundament-Ausfuehrung, gleiches
-- Kieswerk fuer alle Teilflaechen. Nur die Abmessungen (Eingabefeld-Werte,
-- Menge) und die Zugaenglichkeit unterscheiden sich weiterhin pro
-- Teilflaeche - beides bleibt an teilflaeche_eingabefeld_wert bzw.
-- teilflaeche.zugaenglichkeit_stufe. Ersetzt teilflaeche_auswahl (pro
-- Teilflaeche) durch offerte_auswahl (pro Offerte).
--
-- Bestehende Daten werden migriert statt einfach verworfen: pro Offerte +
-- Option wird ein Datensatz uebernommen (falls mehrere Teilflaechen bisher
-- unterschiedliche Kieswerke hatten, gewinnt einer - kann in der Praxis noch
-- kaum vorgekommen sein, da diese Funktion gerade erst gebaut wurde).
-- ============================================================================

create table offerte_auswahl (
  id uuid primary key default gen_random_uuid(),
  offerte_id uuid not null references offerte(id) on delete cascade,
  option_id uuid not null references auswahloption(id) on delete restrict,
  kieswerk_kies_id uuid null references kieswerk_kies(id) on delete restrict,
  kieswerk_beton_id uuid null references kieswerk_beton(id) on delete restrict,
  unique (offerte_id, option_id),
  constraint offerte_auswahl_hoechstens_ein_kieswerk check (
    (case when kieswerk_kies_id is not null then 1 else 0 end
     + case when kieswerk_beton_id is not null then 1 else 0 end) <= 1
  )
);

alter table offerte_auswahl enable row level security;
create policy offerte_auswahl_voller_zugriff on offerte_auswahl
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

insert into offerte_auswahl (offerte_id, option_id, kieswerk_kies_id, kieswerk_beton_id)
select distinct on (t.offerte_id, ta.option_id)
  t.offerte_id, ta.option_id, ta.kieswerk_kies_id, ta.kieswerk_beton_id
from teilflaeche_auswahl ta
join teilflaeche t on t.id = ta.teilflaeche_id
order by t.offerte_id, ta.option_id, ta.kieswerk_kies_id nulls last, ta.kieswerk_beton_id nulls last
on conflict (offerte_id, option_id) do nothing;

drop table teilflaeche_auswahl;
