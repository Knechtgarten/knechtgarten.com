-- ============================================================================
-- Mail-Assistent: Schritt 3a des Mailkategorien-Umbaus - Kategorie/
-- Unterkategorie-Schema anlegen + neue Vorlage-Felder. Rein additiv:
-- bestehende Vorlagen funktionieren unveraendert weiter, das Backend nutzt
-- diese neuen Spalten noch nicht. Ordnet nur die 7 "einfachen" bestehenden
-- Vorlagen zu - die 5 "mit Rueckfrage"-Vorlagen und das vermutete Duplikat
-- "Terminvorschlag vor Ort Bestandeskunden" bleiben bewusst unzugeordnet
-- (folgt in Schritt 3c bzw. nach Stefans Entscheid).
-- ============================================================================

create table if not exists mailassistent_kategorie (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  aktionstyp text not null default 'entwurf',
  reihenfolge integer not null default 0
);

create table if not exists mailassistent_unterkategorie (
  id uuid primary key default gen_random_uuid(),
  kategorie_id uuid not null references mailassistent_kategorie(id) on delete cascade,
  titel text not null,
  aktionstyp text not null default 'entwurf',
  reihenfolge integer not null default 0
);

alter table mailassistent_vorlage add column if not exists kategorie_id uuid references mailassistent_kategorie(id);
alter table mailassistent_vorlage add column if not exists unterkategorie_id uuid references mailassistent_unterkategorie(id);
alter table mailassistent_vorlage add column if not exists nicht_anwenden_bei text;
alter table mailassistent_vorlage add column if not exists verbindlichkeitsgrad text not null default 'angepasst';

insert into mailassistent_kategorie (titel, aktionstyp, reihenfolge)
select * from (values
  ('Kunde', 'entwurf', 0),
  ('Lieferant', 'entwurf', 1),
  ('Mitarbeiter/Team', 'entwurf', 2),
  ('Buchhaltung', 'entwurf', 3),
  ('Architekt/Planer', 'rueckfrage', 4),
  ('Partnerbetrieb', 'entwurf', 5),
  ('Personalbewerbung', 'entwurf', 6),
  ('Behörde/Amt', 'entwurf', 7),
  ('Werbung/Spam', 'rueckfrage', 8)
) as v(titel, aktionstyp, reihenfolge)
where not exists (select 1 from mailassistent_kategorie);

insert into mailassistent_unterkategorie (kategorie_id, titel, aktionstyp, reihenfolge)
select k.id, v.titel, v.aktionstyp, v.reihenfolge
from (values
  ('Kunde', 'Neuanfrage (Erstkontakt)', 'kundenanfrage', 0),
  ('Kunde', 'Bestandskunde / laufendes Projekt', 'entwurf', 1),
  ('Kunde', 'Antwort auf gesendeten Terminvorschlag', 'rueckfrage', 2),
  ('Kunde', 'Terminabsage', 'rueckfrage', 3),
  ('Lieferant', 'Standardbestellung / -anfrage', 'entwurf', 0),
  ('Lieferant', 'Ausführliche / persönliche Konversation', 'entwurf', 1),
  ('Lieferant', 'Terminanfrage / Vertreterbesuch', 'rueckfrage', 2),
  ('Architekt/Planer', 'Devis- / Submissionsanfrage', 'rueckfrage', 0)
) as v(kategorie_titel, titel, aktionstyp, reihenfolge)
join mailassistent_kategorie k on k.titel = v.kategorie_titel
where not exists (select 1 from mailassistent_unterkategorie);

-- Personalbewerbung -> direkt an Kategorie, keine Unterkategorie noetig
update mailassistent_vorlage set kategorie_id = (select id from mailassistent_kategorie where titel = 'Personalbewerbung')
where richtung = 'antworten' and titel = 'Personalbewerbung' and kategorie_id is null;

-- Kunde -> Bestandskunde / laufendes Projekt
update mailassistent_vorlage set
  kategorie_id = (select id from mailassistent_kategorie where titel = 'Kunde'),
  unterkategorie_id = (select id from mailassistent_unterkategorie where titel = 'Bestandskunde / laufendes Projekt')
where richtung = 'antworten'
  and titel in ('Terminvorschlag vor Ort (Bestandeskunde, Diverses)', 'Rückbestätigung', 'Rückerstattung / Bankdaten', 'Probleme mit Pflanzen', 'Service: Reaktion auf Kundenproblem')
  and kategorie_id is null;
