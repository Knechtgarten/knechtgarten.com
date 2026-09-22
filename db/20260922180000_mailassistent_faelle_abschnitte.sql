-- ============================================================================
-- Mail-Assistent: Faelle von 5 fixen Spalten auf frei benannte, einzeln
-- hinzufuegbare/loeschbare Abschnitte umgestellt (gleiches Muster wie
-- Grundlogik) - Titel muessen fuer Stefan aenderbar sein. Migriert die
-- bisherigen 5 Werte 1:1 in Zeilen, damit nichts verloren geht. Ersetzt
-- mailassistent_faelle_meta (bleibt in der DB bestehen, wird vom Tool nicht
-- mehr verwendet).
-- ============================================================================

create table if not exists mailassistent_faelle_abschnitt (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  inhalt text,
  reihenfolge integer not null default 0
);

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Tabu-Liste', tabu_liste, 0 from mailassistent_faelle_meta
where not exists (select 1 from mailassistent_faelle_abschnitt)
limit 1;

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Dankes-Regel', dankes_regel, 1 from mailassistent_faelle_meta
where (select count(*) from mailassistent_faelle_abschnitt) = 1
limit 1;

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Terminvorschläge', terminvorschlaege, 2 from mailassistent_faelle_meta
where (select count(*) from mailassistent_faelle_abschnitt) = 2
limit 1;

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Personen-Rollen-Erkennung',
  coalesce(personen_rollen || '

Die Zeile "Beteiligte Personen laut Mailkopf (Von/An/Cc)" am Anfang der eingehenden Mail ist nur Kontext, NIE Teil des eigentlichen Mailtextes - nicht in der Antwort erwaehnen oder zitieren.', ''),
  3
from mailassistent_faelle_meta
where (select count(*) from mailassistent_faelle_abschnitt) = 3
limit 1;

insert into mailassistent_faelle_abschnitt (titel, inhalt, reihenfolge)
select 'Vollständigkeit', vollstaendigkeit, 4 from mailassistent_faelle_meta
where (select count(*) from mailassistent_faelle_abschnitt) = 4
limit 1;
