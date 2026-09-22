-- ============================================================================
-- Mail-Assistent: Schritt 3c (Datenteil) - loest die 5 bestehenden "Vorlage
-- mit Rueckfrage"-Faelle in Unterkategorien mit mehreren einfachen Vorlagen
-- auf. Text/Label werden per SQL aus der LIVE-Tabelle mailassistent_vorlage_
-- antwort kopiert (nicht abgetippt), damit nichts verloren geht oder sich
-- veraendert. Die alten Vorlagen werden auf aktiv=false gesetzt (nicht
-- geloescht) - dadurch verschwinden sie automatisch aus der KI-Klassifizierung
-- (die Abfrage filtert ohnehin auf aktiv=true), bleiben aber als Verlauf
-- erhalten und sind ueber "Wieder einblenden" jederzeit rueckgaengig zu machen.
-- ============================================================================

-- 1. Architektenanfragen / Devis-Anfragen -> Architekt/Planer > Devis- / Submissionsanfrage
insert into mailassistent_vorlage (titel, inhalt, richtung, typ, kategorie_id, unterkategorie_id, aktiv, reihenfolge, verbindlichkeitsgrad)
select va.label, va.inhalt, 'antworten', 'einfach',
  (select id from mailassistent_kategorie where titel = 'Architekt/Planer'),
  (select id from mailassistent_unterkategorie where titel = 'Devis- / Submissionsanfrage'),
  true, va.reihenfolge, 'exakt'
from mailassistent_vorlage_antwort va
join mailassistent_vorlage p on p.id = va.vorlage_id
where p.titel = 'Architektenanfragen / Devis-Anfragen' and p.richtung = 'antworten'
  and not exists (
    select 1 from mailassistent_vorlage x
    where x.unterkategorie_id = (select id from mailassistent_unterkategorie where titel = 'Devis- / Submissionsanfrage')
  );

-- 2. Werbung, Inserat, Sponsoring -> direkt an Kategorie Werbung/Spam (keine Unterkategorie)
insert into mailassistent_vorlage (titel, inhalt, richtung, typ, kategorie_id, aktiv, reihenfolge, verbindlichkeitsgrad)
select va.label, va.inhalt, 'antworten', 'einfach',
  (select id from mailassistent_kategorie where titel = 'Werbung/Spam'),
  true, va.reihenfolge, 'exakt'
from mailassistent_vorlage_antwort va
join mailassistent_vorlage p on p.id = va.vorlage_id
where p.titel = 'Werbung, Inserat, Sponsoring' and p.richtung = 'antworten'
  and not exists (
    select 1 from mailassistent_vorlage x
    where x.kategorie_id = (select id from mailassistent_kategorie where titel = 'Werbung/Spam') and x.unterkategorie_id is null
  );

-- 3. Service: Terminbestätigung -> Kunde > Antwort auf gesendeten Terminvorschlag
insert into mailassistent_vorlage (titel, inhalt, richtung, typ, kategorie_id, unterkategorie_id, aktiv, reihenfolge, verbindlichkeitsgrad)
select va.label, va.inhalt, 'antworten', 'einfach',
  (select id from mailassistent_kategorie where titel = 'Kunde'),
  (select id from mailassistent_unterkategorie where titel = 'Antwort auf gesendeten Terminvorschlag'),
  true, va.reihenfolge, 'exakt'
from mailassistent_vorlage_antwort va
join mailassistent_vorlage p on p.id = va.vorlage_id
where p.titel = 'Service: Terminbestätigung' and p.richtung = 'antworten'
  and not exists (
    select 1 from mailassistent_vorlage x
    where x.unterkategorie_id = (select id from mailassistent_unterkategorie where titel = 'Antwort auf gesendeten Terminvorschlag')
  );

-- 4. Service: Terminabsage -> Kunde > Terminabsage
insert into mailassistent_vorlage (titel, inhalt, richtung, typ, kategorie_id, unterkategorie_id, aktiv, reihenfolge, verbindlichkeitsgrad)
select va.label, va.inhalt, 'antworten', 'einfach',
  (select id from mailassistent_kategorie where titel = 'Kunde'),
  (select id from mailassistent_unterkategorie where titel = 'Terminabsage'),
  true, va.reihenfolge, 'exakt'
from mailassistent_vorlage_antwort va
join mailassistent_vorlage p on p.id = va.vorlage_id
where p.titel = 'Service: Terminabsage' and p.richtung = 'antworten'
  and not exists (
    select 1 from mailassistent_vorlage x
    where x.unterkategorie_id = (select id from mailassistent_unterkategorie where titel = 'Terminabsage')
  );

-- 5. Vertreter, Aussendienst, Verkaufsberater -> Lieferant > Terminanfrage / Vertreterbesuch
insert into mailassistent_vorlage (titel, inhalt, richtung, typ, kategorie_id, unterkategorie_id, aktiv, reihenfolge, verbindlichkeitsgrad)
select va.label, va.inhalt, 'antworten', 'einfach',
  (select id from mailassistent_kategorie where titel = 'Lieferant'),
  (select id from mailassistent_unterkategorie where titel = 'Terminanfrage / Vertreterbesuch'),
  true, va.reihenfolge, 'exakt'
from mailassistent_vorlage_antwort va
join mailassistent_vorlage p on p.id = va.vorlage_id
where p.titel = 'Vertreter, Aussendienst, Verkaufsberater' and p.richtung = 'antworten'
  and not exists (
    select 1 from mailassistent_vorlage x
    where x.unterkategorie_id = (select id from mailassistent_unterkategorie where titel = 'Terminanfrage / Vertreterbesuch')
  );

-- Alte "mit Rueckfrage"-Vorlagen ausblenden (nicht loeschen)
update mailassistent_vorlage set aktiv = false
where richtung = 'antworten' and typ = 'rueckfrage'
  and titel in (
    'Architektenanfragen / Devis-Anfragen',
    'Werbung, Inserat, Sponsoring',
    'Service: Terminbestätigung',
    'Service: Terminabsage',
    'Vertreter, Aussendienst, Verkaufsberater'
  );
