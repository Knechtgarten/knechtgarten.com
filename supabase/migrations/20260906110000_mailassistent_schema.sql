-- ============================================================================
-- Mail-Assistent - Datenbank-Grundlage.
--
-- Neue Kachel "Tools" auf der Startseite (sichtbar nur fuer Buero-Team +
-- Admin) fuehrt zur Tools-Uebersichtsseite, dort als erster Eintrag der
-- Mail-Assistent. Alle Tabellen fuer dessen Verwaltungsseite: Schreibstil,
-- Firmendaten, Mail-Vorlagen (Verfassen/Antworten, inkl. Rueckfrage-Typ mit
-- mehreren Antwort-Zweigen), Distanzlogik (Projekttypen/Stufen/Partner-
-- betriebe), Sonderfaelle (inkl. Ausnahme-Verknuepfung + Auffangfall),
-- Nachbessern-Buttons, Nutzungs-Log, Einstellungen.
--
-- Startdaten stammen aus dem bisherigen freien Vorgaben-Dokument (Google Doc
-- "Knechtgarten - Vorgaben Mailassistent v9") - werden hier einmalig in die
-- neue, strukturierte Form uebernommen. Wichtige Korrekturen gegenueber dem
-- Doc, die waehrend der Konzeption gemeinsam entschieden wurden:
--  - "Kontaktanfrage" ist keine eigene Vorlage (kein eigener Text), sondern
--    nur der Ausloeser fuer die Distanzlogik - deren Trigger-Kriterium lebt
--    direkt bei mailassistent_distanzlogik_meta.wann_anwenden.
--  - Personalbewerbung ist EIN Vorlage-Eintrag mit Rueckfrage (Ja/Nein-
--    Zweige), nicht zwei getrennte Sonderfaelle (frueherer Entwurfsfehler,
--    haette zu widerspruechlicher Anleitung fuer die KI gefuehrt).
--  - Die Ausnahme "Architekt + Pool" ist ueber ist_ausnahme_von fest mit der
--    Architekten-Regel verknuepft, nicht nur per Fliesstext-Verweis - sonst
--    koennte die Ausnahme beim gezielten Abruf nur der Hauptregel verloren
--    gehen.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Rollen-Helfer: Buero-Team ODER Admin - Sichtbarkeit der Tools-Kachel und
-- Schreibzugriff auf alle Mail-Assistent-Tabellen unten.
-- ----------------------------------------------------------------------------
create or replace function ist_buero_oder_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from benutzer where id = auth.uid() and rolle in ('admin','buero_team'));
$$;

-- ----------------------------------------------------------------------------
-- 1. Startseite: neue Kachel "Tools". "Berechnungstool" wird zu "Rechner"
-- umbenannt (vermeidet Doppelung mit "-tool" im Namen der neuen Kachel).
-- ----------------------------------------------------------------------------
insert into modul_sichtbarkeit
  (modul_key, name, kurzname, titel_mittel, text_gross, icon_key, hintergrund,
   fuer_buero_team, fuer_mitarbeitende, fuer_service_team)
values
  ('tools', 'Tools', 'Tools', 'Tools',
   'Kleine Helfer fuer den Arbeitsalltag, unabhaengig vom Offertentool.',
   'mail', 'grau_dunkel', true, false, false);

update modul_sichtbarkeit
  set name = 'Rechner', titel_mittel = 'Rechner', kurzname = 'Rechner'
  where modul_key = 'berechnungstool';

-- ----------------------------------------------------------------------------
-- 2. Schreibstil (ein versionierter Eintrag).
-- ----------------------------------------------------------------------------
create table mailassistent_schreibstil (
  id uuid primary key default gen_random_uuid(),
  inhalt text not null,
  version int not null default 1,
  immer_verfassen boolean not null default true,
  immer_antworten boolean not null default true,
  aktualisiert_am timestamptz not null default now(),
  aktualisiert_von text
);

insert into mailassistent_schreibstil (inhalt, version, aktualisiert_von) values (
$vorgabe$Schweizer Hochdeutsch, gut lesbar und natuerlich.
Ruhig, klar, locker, frisch, freundlich, wertig, bodenstaendig und ehrlich.
Lieber einfach als kompliziert. Einfach, aber nicht umgangssprachlich.
Kurze Saetze und kurze Absaetze. Viel Luft im Text.

Die Texte sollen wie von einem erfahrenen Handwerker/Gartengestalter geschrieben sein: persoenlich, kompetent und ruhig.
Ziel: Der Kunde soll spueren: Hier schreibt ein Mensch.

Grundsaetze:
Nur das schreiben, was wirklich relevant ist. Eine klare Aussage ist besser als ein schoener Satz.
Freundlichkeit entsteht durch Respekt und Klarheit, nicht durch zusaetzliche Worte - aber nicht wegkuerzen.
Kurze, natuerliche Dankesworte bleiben im Text, wenn sie passen ("Vielen Dank", "Herzlichen Dank") - keine uebertriebenen Dankesformeln.
Bei Kundenmails wenn passend "ich" statt "wir" verwenden.

Inhalt:
Keine zusaetzlichen Erklaerungen erfinden, keine Gruende ergaenzen, die nicht genannt wurden, keine Werte/Botschaften hineininterpretieren.
Vermutungen als Vermutung formulieren, nicht als Tatsache. Nichts dazudichten.

Vermeiden:
Keine Gedankenstriche (ausser bei Terminlisten). Keine Behoerden-/Marketingwoerter, keine Uebertreibungen, keine Floskeln, keine Buzzwords.
Keine Rechtfertigungen, kein Verkaufsdruck, nicht wie Werbung, nicht wie eine Vorlage, keine unnoetigen Fuellwoerter.
Vermeide insbesondere: "nachfolgend", "bezueglich", "betreffend", "hiermit", "duerfen Sie", "wir moechten uns bedanken", "wir freuen uns sehr".

Anrede: immer mit Sie antworten, ausser der Kunde schreibt mit Du an oder unterschreibt nur mit Vornamen.
Bei Sie: "Guten Tag, [Frau/Herr Name]" oder einfach "Guten Tag". Bei Du: "Liebe/r [Vorname]".

Grussformel: Standard "Freundliche Gruesse", waermer (z.B. Terminbestaetigung) "Herzliche Gruesse aus Heimenschwand".

Signatur: bei einem Entwurf nur die in Gmail bereits eingerichtete Signatur des Mitarbeiters verwenden, nicht selbst erfinden.

Terminvorschlaege - Format: immer mit Gedankenstrich, nicht nummeriert:
– [Datum, Uhrzeit]
– [Datum, Uhrzeit]
Danach: "Ich freue mich auf Ihre Rueckmeldung, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir einen Alternativtermin vorschlagen."

Laenge je nach Empfaenger:
- Kunden: ganze Saetze, freundlich und klar, so kurz wie moeglich
- Lieferanten / Buchhaltung: nur das Noetigste, sehr knapp, ganze Saetze
- Intern (Stefan, Pascal, Benu, Fabian): Stichworte reichen, keine ganzen Saetze noetig

Termine: Offerten-/Besichtigungstermine ca. 3 Wochen im Voraus, fruehestens in 12 Arbeitstagen. Offerten selbst: 3-4 Wochen Lieferzeit.
Keine verbindlichen Preisangaben oder Zusagen gegenueber Kunden machen.
Falls das Original auf Englisch ist, auch auf Englisch antworten.$vorgabe$,
  9, 'Migration (aus Google Doc v9 uebernommen)'
);

-- ----------------------------------------------------------------------------
-- 3. Firmendaten (ein Eintrag) + Mitarbeiterliste.
-- ----------------------------------------------------------------------------
create table mailassistent_firmendaten (
  id uuid primary key default gen_random_uuid(),
  name_kunden text not null default 'Knechtgarten',
  name_rechnungen text not null default 'Knecht AG Naturnahe Gärten',
  adresse text not null default 'Badhaus 42, 3615 Heimenschwand',
  telefon text default '033 453 10 20',
  mobile text default '079 305 39 00',
  web text default 'knechtgarten.ch',
  mwst_nummer text default 'CHE-109.466.032',
  bank text default 'Raiffeisenbank Steffisburg',
  iban text default 'CH68 8080 8009 0635 6577 8',
  swift_bic text default 'RAIFCH22',
  immer_verfassen boolean not null default true,
  immer_antworten boolean not null default true,
  aktualisiert_am timestamptz not null default now(),
  aktualisiert_von text
);
insert into mailassistent_firmendaten (aktualisiert_von) values ('Migration');

create table mailassistent_mitarbeiter (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text not null,
  funktion text,
  reihenfolge int not null default 0
);
insert into mailassistent_mitarbeiter (name, email, funktion, reihenfolge) values
  ('Stefan Knecht', 'mail@knechtgarten.ch', 'Geschäftsführer / Inhaber', 1),
  ('Pascal Wüthrich', 'pascal.wuethrich@knechtgarten.ch', 'Eidg. dipl. Gartenbautechniker | Gartenplaner | Beratung', 2),
  ('Benjamin Habegger', 'bau@knechtgarten.ch', 'Projektleiter Gartenbau', 3),
  ('Fabian Oberholzer', 'fabian.oberholzer@knechtgarten.ch', 'Projektleiter Gartenbau', 4);

-- ----------------------------------------------------------------------------
-- 4. Mail-Vorlagen (Verfassen + Antworten). typ='rueckfrage' Eintraege haben
-- eine frage + mehrere Zweige in mailassistent_vorlage_antwort statt eines
-- einzelnen inhalt-Texts.
-- ----------------------------------------------------------------------------
create table mailassistent_vorlage (
  id uuid primary key default gen_random_uuid(),
  richtung text not null check (richtung in ('verfassen','antworten')),
  titel text not null,
  typ text not null default 'einfach' check (typ in ('einfach','rueckfrage')),
  inhalt text,
  frage text,
  wann_trifft_zu text,
  reihenfolge int not null default 0,
  erstellt_am timestamptz not null default now(),
  aktualisiert_am timestamptz not null default now()
);

create table mailassistent_vorlage_antwort (
  id uuid primary key default gen_random_uuid(),
  vorlage_id uuid not null references mailassistent_vorlage(id) on delete cascade,
  label text not null,
  inhalt text not null,
  reihenfolge int not null default 0
);

-- Verfassen
insert into mailassistent_vorlage (richtung, titel, reihenfolge, inhalt) values
('verfassen', 'Offerte', 1, $t$Guten Tag [NAME]

Wie besprochen senden wir Ihnen die Offerte für [PROJEKT] im Anhang zu.

Wir haben uns sehr gefreut, Ihr Projekt kennenzulernen, und sind überzeugt, dass wir gemeinsam etwas Schönes realisieren können.

Für Fragen stehen wir Ihnen gerne zur Verfügung – melden Sie sich einfach. Gerne nehmen wir uns auch Zeit für ein persönliches Gespräch, falls Sie die Offerte besprechen möchten.

Die Offerte ist 30 Tage gültig.

Freundliche Grüsse$t$),
('verfassen', 'Gartenplanung', 2, $t$Guten Tag [NAME]

Im Anhang finden Sie unsere Offerte für eine Gartenplanung.

Eine professionelle Planung lohnt sich: Unser Gartenplaner Pascal Wüthrich (Eidg. dipl. Gartenbautechniker) nimmt sich Zeit für Ihre Wünsche, entwickelt ein durchdachtes Konzept und zeigt Ihnen, wie Ihr Garten aussehen könnte – bevor auch nur ein Stein gesetzt wird.

Was die Planung beinhaltet:
– Persönliches Gespräch und Aufnahme Ihrer Wünsche vor Ort
– Professionelle Gartenplanung mit Visualisierung
– Detaillierter Kostenvoranschlag für die Umsetzung
– 50% der Planungskosten werden bei Auftragserteilung angerechnet

Für Fragen stehen wir Ihnen gerne zur Verfügung.

Freundliche Grüsse$t$);

-- Antworten (typ='einfach')
insert into mailassistent_vorlage (richtung, titel, reihenfolge, wann_trifft_zu, inhalt) values
('antworten', 'Nachhaken', 1,
 'Zweite Anfrage beim gleichen Kunden, nachdem eine Offerte verschickt wurde und länger keine Antwort kam.',
 $t$Guten Tag [NAME]

Wir wollten kurz nachfragen, ob Sie unsere Offerte erhalten haben und ob noch Fragen offen sind.

Falls Sie die Offerte besprechen möchten, stehen wir gerne für ein kurzes Gespräch zur Verfügung.

Freundliche Grüsse$t$),
('antworten', 'Terminvorschlag Diverses (Bestandeskunde)', 2,
 'Bestehender Kunde meldet sich mit einem konkreten Anliegen vor Ort (Reparatur, Nachbesserung, allgemeine Situation) – kein Neukunden-Erstkontakt.',
 $t$Guten Tag

Vielen Dank für Ihre Nachricht.

Am besten sehe ich mir die Situation direkt vor Ort an. So kann ich mir ein genaues Bild machen und wir können gemeinsam die nächsten Schritte besprechen.

Von meiner Seite sind folgende Termine möglich:
– [Datum, Uhrzeit]
– [Datum, Uhrzeit]

Teilen Sie mir gerne mit, welcher Termin für Sie am besten passt. Sollte keiner der Vorschläge möglich sein, können Sie mir gerne einen Alternativtermin vorschlagen.

Bis bald, ich wünsche Ihnen eine gute Zeit.

Herzliche Grüsse aus Heimenschwand$t$),
('antworten', 'Terminbestätigung', 3,
 'Kunde bestätigt einen zuvor vorgeschlagenen Termin.',
 $t$Guten Tag

Herzlichen Dank für die Nachricht.

Der Besprechungstermin am [Datum, Uhrzeit] passt gut. Ich habe mir den Termin in meinem Kalender notiert.

Falls sich bei Ihnen noch etwas ändern sollte, melden Sie sich einfach kurz bei mir.

Ich freue mich auf die Besprechung.

Herzliche Grüsse aus Heimenschwand$t$),
('antworten', 'Architekten-Absage', 4,
 'Anfrage von einem Architekturbüro/Devis-/Submissionsanfrage – siehe Sonderfall "Architekten- / Devis-Anfragen" (Ausnahme: Pool/Naturteich).',
 $t$Guten Tag

Vielen Dank für Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Leider können wir Ihnen für dieses Projekt keine Offerte ausarbeiten. Unsere Kapazitäten sind für die nächsten fünf Monate bereits vollständig verplant.

Unser Schwerpunkt liegt zudem hauptsächlich bei Gartenprojekten für Privatkunden.

Wir wünschen Ihnen für die weitere Planung und Umsetzung gutes Gelingen.

Freundliche Grüsse$t$),
('antworten', 'Werbung-Absage', 5,
 'Anfrage zu Werbung, Inserat, Sponsoring oder Anzeige – siehe Sonderfall "Werbung / Inserate / Sponsoring".',
 $t$Guten Tag

Vielen Dank für Ihre Anfrage und Ihr Interesse an einer Zusammenarbeit.

Unser Budget für Werbung und Sponsoring ist für dieses Jahr bereits vergeben. Aus diesem Grund können wir Ihre Anfrage leider nicht berücksichtigen.

Wir danken Ihnen für Ihr Verständnis und wünschen Ihnen alles Gute.

Freundliche Grüsse$t$),
('antworten', 'Rückerstattung', 6,
 'Absender fragt nach Bankangaben für eine Rückerstattung (z.B. Doppelzahlung).',
 $t$Guten Tag

Hier finden Sie die Angaben für die Rückerstattung:

[NAME_RECHNUNGEN]
[ADRESSE]

IBAN: [IBAN]
SWIFT-BIC: [SWIFT_BIC]

Vielen Dank für die Rückerstattung.

Freundliche Grüsse$t$);

-- Antworten (typ='rueckfrage') - Personalbewerbung
insert into mailassistent_vorlage (richtung, titel, typ, frage, wann_trifft_zu, reihenfolge)
values ('antworten', 'Personalbewerbung', 'rueckfrage', 'Zum Gespräch einladen?',
  'Eingehende Bewerbung auf eine offene Stelle oder Initiativbewerbung.', 7);

insert into mailassistent_vorlage_antwort (vorlage_id, label, inhalt, reihenfolge)
select id, 'Ja, einladen', $t$Guten Tag

Vielen Dank für Ihre Bewerbung und Ihr Interesse an unserem Betrieb.

Ihr Dossier hat uns angesprochen. Wir möchten Sie gerne zu einem persönlichen Gespräch bei uns einladen.

Von unserer Seite sind folgende Termine möglich:
– [Datum, Uhrzeit]
– [Datum, Uhrzeit]

Teilen Sie uns gerne mit, welcher Termin für Sie am besten passt.

Wir freuen uns, Sie persönlich kennenzulernen.

Freundliche Grüsse$t$, 1
from mailassistent_vorlage where richtung = 'antworten' and titel = 'Personalbewerbung';

insert into mailassistent_vorlage_antwort (vorlage_id, label, inhalt, reihenfolge)
select id, 'Nein, absagen', $t$Guten Tag

Vielen Dank für Ihre Bewerbung und Ihr Interesse an unserem Betrieb.

Wir haben Ihre Unterlagen geprüft. Leider können wir Ihre Bewerbung nicht berücksichtigen.

Wir wünschen Ihnen für die weitere Suche alles Gute.

Freundliche Grüsse$t$, 2
from mailassistent_vorlage where richtung = 'antworten' and titel = 'Personalbewerbung';

-- ----------------------------------------------------------------------------
-- 5. Sonderfaelle (inkl. Ausnahme-Verknuepfung + Auffangfall).
-- ----------------------------------------------------------------------------
create table mailassistent_sonderfall (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  stichwoerter text,
  verhalten text,
  ist_ausnahme_von uuid references mailassistent_sonderfall(id),
  ist_auffangfall boolean not null default false,
  immer_verfassen boolean not null default false,
  immer_antworten boolean not null default true,
  reihenfolge int not null default 0
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, reihenfolge) values
('Architekten- / Devis-Anfragen', 'Architekt, Architektin, Architekturbüro, Devis, Submission',
 'Absagen (Vorlage "Architekten-Absage"). Ausnahme siehe unten: Pool- oder Naturteichanfrage.', 1),
('Werbung / Inserate / Sponsoring', 'Werbung, Inserat, Sponsoring, Anzeige, Mediapartner',
 'Absagen (Vorlage "Werbung-Absage").', 2),
('Kein Ort erkennbar', 'Weder PLZ noch Ortsname in der Anfrage erkennbar',
 'Nicht absagen und keine Distanz-Zone annehmen – immer zuerst nach der Adresse fragen ("Könnten Sie mir noch Ihre Adresse mitteilen?").', 3);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, ist_ausnahme_von, reihenfolge)
select 'Architekt + Pool/Naturteich (Ausnahme)', 'Pool, Schwimmteich, Naturteich (zusätzlich zu den Architekt-Stichwörtern)',
  'Kein Absagemail – normal nach Distanzlogik bearbeiten. Wird automatisch mitgeschickt, sobald die Architekten-Regel zutrifft.',
  id, 4
from mailassistent_sonderfall where titel = 'Architekten- / Devis-Anfragen';

insert into mailassistent_sonderfall (titel, verhalten, ist_auffangfall, reihenfolge) values
('Kein Sonderfall trifft eindeutig zu',
 'KI schreibt frei nach Schreibstil. Bei echter Unklarheit zuerst eine Rückfrage stellen statt zu raten.',
 true, 99);

-- ----------------------------------------------------------------------------
-- 6. Distanzlogik: Projekttypen (KI-Klassifizierung), Stufen (editierbare
-- Fahrzeit-Grenzen statt interner "Zone"-Begriffe), Partnerbetriebe,
-- gemeinsame Einstellungen (Umkreis-Schwelle + Trigger-Beschreibung).
-- ----------------------------------------------------------------------------
create table mailassistent_distanz_projekttyp (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  beschreibung text,
  reihenfolge int not null default 0
);

create table mailassistent_distanz_stufe (
  id uuid primary key default gen_random_uuid(),
  projekttyp_id uuid not null references mailassistent_distanz_projekttyp(id) on delete cascade,
  bis_minuten int,
  vorlage_text text not null,
  ist_partner_logik boolean not null default false,
  reihenfolge int not null default 0
);

create table mailassistent_partnerbetrieb (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  adresse text not null,
  geprueft_ok boolean,
  geprueft_fehler text,
  geprueft_am timestamptz,
  reihenfolge int not null default 0
);

create table mailassistent_distanzlogik_meta (
  id uuid primary key default gen_random_uuid(),
  wann_anwenden text not null default
    'Erste Anfrage eines potenziellen Neukunden nach Angebot oder Besichtigung – meist eingehend über info@knechtgarten.ch, an Büro-Mitarbeiter weitergeleitet. Nicht bei laufenden Projekten oder bestehenden Kunden.',
  partner_umkreis_minuten int not null default 35
);
insert into mailassistent_distanzlogik_meta default values;

-- Projekttypen mit Startdaten (Fahrzeit-Grenzen aus Wassergarten/Allgemein/
-- Bauteile 1:1 aus dem Google Doc uebernommen; Zone 3A/4A hatten dort beide
-- "60-80 Min" - vermutlich ein Tippfehler im Original, hier als "danach"
-- aufgeloest, bitte pruefen. Die vier Pflege-Unterarten sind neu (frueher
-- eine gemeinsame Zone mit 4 Vorlagen) und uebernehmen vorlaeufig die
-- Bauteile-Fahrzeiten als Ausgangswert.)
insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
('Wassergarten', 'Pool, Schwimmteich, Badebrunnen', 1),
('Terrasse', 'Terrassenbau, Sitzplatz', 2),
('Allgemein', 'Allgemeine Gartenanlagen, Gartengestaltung, Bepflanzung, Bewässerungsanlage', 3),
('Bauteile', 'Einzelne Bauteile wie Holzdeck, Rasen, Belag', 4),
('Poolreinigung', 'Reinigung/Unterhalt eines bestehenden Pools – kein Neubau/Umbau', 5),
('Teichreinigung', 'Reinigung/Unterhalt Schwimmteich oder Naturteich – kein Neubau/Umbau', 6),
('Belagreinigung', 'Reinigung von Platten/Belägen', 7),
('Gartenpflege', 'Laufender Gartenunterhalt, Heckenschnitt, Rasenpflege', 8);

insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, s.bis, s.txt, s.partner, s.reihe
from mailassistent_distanz_projekttyp,
  lateral (values
    (40, 'Vor-Ort-Besichtigung anbieten', false, 1),
    (60, 'Drei Varianten (Fotos / Besprechung vor Ort / Planungsauftrag)', false, 2),
    (80, 'Planungsauftrag mit Zusatzkosten', false, 3),
    (null, 'Partner-Empfehlung prüfen', true, 4)
  ) as s(bis, txt, partner, reihe)
where titel in ('Wassergarten', 'Terrasse');

insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, s.bis, s.txt, s.partner, s.reihe
from mailassistent_distanz_projekttyp,
  lateral (values
    (30, 'Vor-Ort-Besichtigung anbieten', false, 1),
    (50, 'Drei Varianten (Fotos / Besprechung vor Ort / Planungsauftrag)', false, 2),
    (70, 'Planungsauftrag mit Zusatzkosten', false, 3),
    (null, 'Partner-Empfehlung prüfen', true, 4)
  ) as s(bis, txt, partner, reihe)
where titel = 'Allgemein';

insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, s.bis, s.txt, s.partner, s.reihe
from mailassistent_distanz_projekttyp,
  lateral (values
    (30, 'Foto-basierte Kostenschätzung', false, 1),
    (40, 'Foto-basierte Kostenschätzung', false, 2),
    (null, 'Partner-Empfehlung prüfen', true, 3)
  ) as s(bis, txt, partner, reihe)
where titel in ('Bauteile', 'Poolreinigung', 'Teichreinigung', 'Belagreinigung', 'Gartenpflege');

insert into mailassistent_partnerbetrieb (name, adresse, reihenfolge) values
('Gärten und mehr AG', 'Lerchenfeld 9, 9601 Lütisburg Station · 071 931 20 88', 1),
('Ihre Gartenwelt AG', 'Grünaustrasse 24, 5712 Beinwil am See · 062 771 00 95', 2),
('Wetzel Gärten', 'Mellingerstrasse 13, 5413 Birmenstorf · 056 225 17 03', 3);

-- ----------------------------------------------------------------------------
-- 7. Nachbessern-Buttons (Schnellauswahl fuers Nachbessern im Gmail-Panel).
-- ----------------------------------------------------------------------------
create table mailassistent_nachbessern_button (
  id uuid primary key default gen_random_uuid(),
  titel text not null,
  anweisung text not null,
  reihenfolge int not null default 0
);
insert into mailassistent_nachbessern_button (titel, anweisung, reihenfolge) values
('Kürzer', 'Fasse den Text deutlich kürzer, ohne wichtige Informationen zu verlieren.', 1),
('Lockerer', 'Schreibe etwas lockerer und persönlicher, aber weiterhin professionell.', 2);

-- ----------------------------------------------------------------------------
-- 8. Einstellungen (API/Modell) + Nutzungs-Log.
-- ----------------------------------------------------------------------------
create table mailassistent_einstellungen (
  id uuid primary key default gen_random_uuid(),
  anthropic_modell text not null default 'claude-sonnet-5'
);
insert into mailassistent_einstellungen default values;

create table mailassistent_nutzung_log (
  id uuid primary key default gen_random_uuid(),
  mitarbeiter_email text not null,
  richtung text check (richtung in ('verfassen','antworten')),
  vorlage_id uuid references mailassistent_vorlage(id),
  tokens_input int not null default 0,
  tokens_output int not null default 0,
  erstellt_am timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 9. RLS: alle mailassistent_* Tabellen nur fuer Buero-Team/Admin lesbar UND
-- schreibbar (kein abgestuftes Lese-vs-Schreib-Recht wie bei Tool B/C - siehe
-- ist_buero_oder_admin() oben).
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'mailassistent_schreibstil','mailassistent_firmendaten','mailassistent_mitarbeiter',
    'mailassistent_vorlage','mailassistent_vorlage_antwort','mailassistent_sonderfall',
    'mailassistent_distanz_projekttyp','mailassistent_distanz_stufe','mailassistent_partnerbetrieb',
    'mailassistent_distanzlogik_meta','mailassistent_nachbessern_button',
    'mailassistent_einstellungen','mailassistent_nutzung_log'
  ] loop
    execute format('alter table %I enable row level security;', t);
    execute format('create policy %I_buero_admin on %I for all using (ist_buero_oder_admin()) with check (ist_buero_oder_admin());', t, t);
  end loop;
end $$;
