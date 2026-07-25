-- ============================================================================
-- Offertentool 2027 - Rueckbau: Options-/Kieswerk-Wahl zurueck auf "pro
-- Teilflaeche" statt "geteilt pro Bauteil/Offerte".
--
-- Die letzte Session hatte dies auf "geteilt" umgestellt, um ein enges
-- Problem zu loesen (Kieswerk-Eindeutigkeit bei kuenftigem Pooling). Das war
-- zu weitgehend: der Nutzer braucht z.B., dass Teilflaeche A eine
-- "Kies-Fundament"-Option bekommt und Teilflaeche B nicht - das war mit
-- geteilter Konfiguration nicht abbildbar. Ersetzt offerte_auswahl wieder
-- durch teilflaeche_auswahl (urspruengliche Struktur).
-- ============================================================================

create table teilflaeche_auswahl (
  id uuid primary key default gen_random_uuid(),
  teilflaeche_id uuid not null references teilflaeche(id) on delete cascade,
  option_id uuid not null references auswahloption(id) on delete restrict,
  kieswerk_kies_id uuid null references kieswerk_kies(id) on delete restrict,
  kieswerk_beton_id uuid null references kieswerk_beton(id) on delete restrict,
  unique (teilflaeche_id, option_id),
  constraint teilflaeche_auswahl_hoechstens_ein_kieswerk check (
    (case when kieswerk_kies_id is not null then 1 else 0 end
     + case when kieswerk_beton_id is not null then 1 else 0 end) <= 1
  )
);

alter table teilflaeche_auswahl enable row level security;
create policy teilflaeche_auswahl_voller_zugriff on teilflaeche_auswahl
  for all using (ist_eingeloggter_benutzer()) with check (ist_eingeloggter_benutzer());

-- Best effort zurueckkopieren: jede aktuelle Teilflaeche einer Offerte
-- bekommt dieselbe (bisher geteilte) Auswahl - echte pro-Teilflaeche-
-- Unterscheidung ist zwischenzeitlich verloren gegangen (nur Testdaten
-- betroffen, da die Funktion gerade erst gebaut wurde).
insert into teilflaeche_auswahl (teilflaeche_id, option_id, kieswerk_kies_id, kieswerk_beton_id)
select t.id, oa.option_id, oa.kieswerk_kies_id, oa.kieswerk_beton_id
from offerte_auswahl oa
join teilflaeche t on t.offerte_id = oa.offerte_id;

drop table offerte_auswahl;
