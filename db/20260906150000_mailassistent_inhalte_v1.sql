-- ============================================================================
-- Mail-Assistent - Inhalte aus "Knechtgarten - Vorgaben Mailassistent v9"
-- (Google Doc), uebertragen in die neue Datenbankstruktur.
--
-- Abweichungen vom Original-Doc, die bewusst so umgesetzt wurden (Entscheide
-- aus der gemeinsamen Besprechung waehrend der Konzeption):
--  - Personalbewerbung: EIN Vorlage-Eintrag mit Rueckfrage (statt zwei
--    getrennte Sonderfaelle "Einladen"/"Absagen").
--  - Architekt-Ausnahme (Pool/Naturteich): als echte DB-Verknuepfung
--    (ist_ausnahme_von), nicht nur als Fliesstext-Hinweis.
--  - "Typ D - Pflege" aus dem Doc wurde in 4 eigene Projekttypen aufgeteilt:
--    Poolreinigung / Teichreinigung / Belagreinigung / Gartenpflege. Ebenso
--    wurde "Typ A - Wassergarten und Terrassen" in zwei Projekttypen
--    aufgeteilt: Wassergarten / Terrasse (eigener Vorschlag von Stefan).
--
-- WICHTIG - bitte beim Durchlesen besonders pruefen:
--  1. Die Minuten-Schwellen bei Wassergarten/Terrasse: Das Original-Doc hatte
--     Zone 3A UND Zone 4A beide mit "60-80 Min." angegeben (vermutlich ein
--     Tippfehler im Doc). Ich bin davon ausgegangen, dass ab 80 Minuten die
--     Partnerbetrieb-Logik greift (analog zu Typ C/D, wo ab der jeweils
--     naechsten Zone abgesagt wird). Bitte diese Schwelle nochmals pruefen.
--  2. Der "Auffangfall" (greift wenn wirklich nichts anderes passt) stand so
--     nicht im Doc - ich habe einen neutralen Platzhalter-Text eingetragen,
--     den ihr sicher anpassen wollt.
--  3. Die Partnerbetriebe haben in der Datenbank nur Name + Adresse (keine
--     eigenen Felder fuer Telefon/Website) - ich habe Telefon und Website
--     darum mit in das Adressfeld gepackt, damit die KI sie trotzdem kennt.
--  4. Nachbessern-Buttons standen nicht im Doc - ich habe 4 naheliegende
--     Vorschlaege ergaenzt (kuerzer/foermlicher/anderer Termin/direkter),
--     die ihr nach Bedarf loeschen oder anpassen koennt.
--  5. Mail-Vorlagen fuer "Verfassen" (neue Mail): das Doc enthaelt dazu keine
--     eigenen Vorlagen (nur fuer "Antworten") - hier bleibt bewusst nichts
--     eingetragen, das muesstet ihr separat ergaenzen.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Schreibstil (Update der bestehenden Start-Zeile)
-- ----------------------------------------------------------------------------
update mailassistent_schreibstil set
  immer_verfassen = true,
  immer_antworten = true,
  inhalt = 'GRUNDTON
Schweizer Hochdeutsch, gut lesbar und natuerlich.
Ruhig, klar, locker, frisch, freundlich, wertig, bodenstaendig und ehrlich.
Lieber einfach als kompliziert. Einfach, aber nicht umgangssprachlich.
Kurze Saetze und kurze Absaetze. Viel Luft im Text.
Die Texte sollen wie von einem erfahrenen Handwerker/Gartengestalter geschrieben sein: persoenlich, kompetent und ruhig.
Ziel: Der Kunde soll spueren: Hier schreibt ein Mensch. Ein erfahrener, kompetenter Gartengestalter, der sein Handwerk versteht, sorgfaeltig arbeitet, zuverlaessig und professionell ist.

GRUNDSAETZE
Nur das schreiben, was wirklich relevant ist.
Eine klare Aussage ist besser als ein schoener Satz.
Freundlichkeit entsteht durch Respekt und Klarheit, nicht durch zusaetzliche Worte. Freundlichkeit aber nicht wegkuerzen.
Kurze, natuerliche Dankesworte bleiben im Text, wenn sie passen. Ein einfaches "Vielen Dank" oder "Herzlichen Dank" ist erwuenscht - keine uebertriebenen Dankesformeln oder Standardfloskeln.
Bei Kundenmails wenn passend "ich" statt "wir" verwenden.

INHALT
Keine zusaetzlichen Erklaerungen erfinden. Keine Gruende ergaenzen, die nicht genannt wurden.
Keine Werte oder Botschaften hineininterpretieren. Vermutungen als Vermutung formulieren, nicht als Tatsache. Nichts dazudichten.

VERMEIDEN
Keine Gedankenstriche (ausser bei Terminlisten, siehe unten). Keine Behoerden- oder Marketingwoerter. Keine Uebertreibungen. Keine Floskeln. Keine Buzzwords. Keine Rechtfertigungen. Kein Verkaufsdruck. Nicht wie Werbung. Nicht wie eine Vorlage. Keine unnoetigen Fuellwoerter. Keine kuenstlich emotionalen Formulierungen. Keine Standardsaetze. Keine kuenstliche Wertschaetzung. Keine uebertriebene Dankbarkeit. Kein Ausschmuecken. Keine Erklaerungen, die selbstverstaendlich sind.
Vermeide insbesondere Woerter/Formulierungen wie: "nachfolgend", "bezueglich", "betreffend", "hiermit", "duerfen Sie", "wir moechten uns bedanken", "wir freuen uns sehr".

TON
Persoenlich und direkt, aber nie aufdringlich. Bei Kundenmails wenn moeglich "ich" statt "wir", damit es persoenlicher wirkt. Freundlich, aber nicht uebertrieben freundlich. Professionell, aber nicht distanziert.

ANREDE
Immer mit Sie antworten, ausser der Kunde schreibt einen mit Du an oder unterschreibt nur mit seinem Vornamen.
Bei Sie: "Guten Tag, [Frau/Herr Name]" oder einfach "Guten Tag".
Bei Du: "Liebe/r [Vorname]".

GRUSSFORMEL
Standard: "Freundliche Gruesse". Waermer, z.B. bei Terminbestaetigung: "Herzliche Gruesse aus Heimenschwand".

SIGNATUR
Beim Entwurf nur die Signatur von Gmail verwenden - jeder Mitarbeitende hat seine Signatur in Gmail bereits eingerichtet, darum im Entwurf selbst keine eigene Signatur/Grussformel-Unterschrift ausformulieren ausser der Grussformel selbst.

TERMINVORSCHLAEGE - FORMAT
Immer mit Gedankenstrich, nicht nummeriert:
- [Datum, Uhrzeit]
- [Datum, Uhrzeit]
Danach: "Ich freue mich auf Ihre Rueckmeldung, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir einen Alternativtermin vorschlagen."

LAENGE JE NACH EMPFAENGER
- Kunden: ganze Saetze, freundlich und klar, so kurz wie moeglich.
- Lieferanten: nur das Noetigste, sehr knapp, ganze Saetze.
- Buchhaltung (Tschanz Treuhand): nur das Noetigste, sehr knapp, ganze Saetze.
- Intern (Stefan, Pascal, Benu, Fabian): Stichworte reichen, keine ganzen Saetze noetig.

ALLGEMEINE VERHALTENSREGELN
Unsicherheit bei der Antwort: Wenn nicht klar ist, welche Antwort passt, immer zwei Textvorschlaege (Variante A und Variante B) mit kurzem Hinweis, worin sie sich unterscheiden. Beide Varianten vollstaendig ausformulieren, direkt hintereinander im selben Entwurf, dazwischen eine Trennlinie "---".

Abschliessend schreiben - Grundregel: Ziel ist, dass die naechste Handlung beim Kunden liegt, nicht bei uns. Wo immer moeglich Terminvorschlaege machen, Fragen stellen oder um Bestaetigung bitten, damit wir nicht nochmals nachhaken muessen.

Wenn wir intern noch klaeren muessen: Wenn nicht vermeidbar, trotzdem konkret bleiben - immer eine Frist setzen ("ich melde mich bis [Datum]"), niemals offen lassen ("ich schaue nach", "demnaechst", "in Kuerze"). Bei Unsicherheit zwei Varianten in den Entwurf schreiben: Variante A abschliessend (Handlung beim Kunden), Variante B wir klaeren intern mit konkretem Datum.

Platzhalter fuer Termine - immer konkret, nie vage:
- Lieferung: "voraussichtlich ab [Lieferdatum, KW XX]"
- Montage: "Montagetermin: [Datum, KW XX]"
- Ausfuehrung: "Ausfuehrung geplant fuer [KW XX]"
- Rueckruf: "ich rufe Sie am [Datum] an"
- Intern: "ich melde mich bis [Datum]"

Nachbesserung/Reklamation bestehender Kunde: Bei konkreten Rueckmeldungen von Bestandskunden direkt einen Termin fixieren (Freihalter im Entwurf), nicht nur ankuendigen, dass man sich meldet - ausser die Anfrage ist zu unkonkret, um einen Termin zu machen.

Termine allgemein: Offertentermine und Vor-Ort-Besichtigungen ca. 3 Wochen im Voraus, fruehestens in 12 Arbeitstagen. Immer KW-Angabe, 2 konkrete Termine, Format Gedankenstrich-Liste, Hinweis dass der Kunde einen Alternativtermin vorschlagen kann.

Terminlogik: Bei einer KONKRETEN Anfrage (klarer Handlungsbedarf, Nachbesserung, bestehender Auftrag) direkt einen Terminvorschlag machen - Datum als Freihalter [Datum, Uhrzeit] eintragen. Bei einer UNKONKRETEN Anfrage (unklar was genau gewuenscht wird, zu wenig Infos) zuerst Rueckfragen stellen.

Offerten & Termine allgemein: Offerten 3-4 Wochen Lieferzeit. Neukunden ohne Fotos: zuerst Fotos anfordern.

Stundenansaetze (nur intern, nie an Kunden kommunizieren): Standard 148.- Fr./Std, Teichreinigung 98.- Fr./Std, Baubewilligung 148.- Fr./Std (ca. 10 Std total).',
  aktualisiert_am = now(),
  aktualisiert_von = 'Migration aus Vorgaben-Doc v9'
where true;

-- ----------------------------------------------------------------------------
-- 2. Firmendaten (Update der bestehenden Start-Zeile)
-- ----------------------------------------------------------------------------
update mailassistent_firmendaten set
  name_kunden = 'Knechtgarten',
  name_rechnungen = 'Knecht AG Naturnahe Gaerten',
  adresse = 'Badhaus 42, 3615 Heimenschwand',
  telefon = '033 453 10 20',
  mobile = '079 305 39 00',
  web = 'knechtgarten.ch',
  mwst_nummer = 'CHE-109.466.032',
  bank = 'Raiffeisenbank Steffisburg (IID/BC-Nr. 80808)',
  iban = 'CH68 8080 8009 0635 6577 8',
  swift_bic = 'RAIFCH22',
  immer_verfassen = true,
  immer_antworten = true,
  aktualisiert_am = now(),
  aktualisiert_von = 'Migration aus Vorgaben-Doc v9'
where true;

-- ----------------------------------------------------------------------------
-- 3. Mitarbeiter
-- ----------------------------------------------------------------------------
insert into mailassistent_mitarbeiter (name, email, funktion, reihenfolge) values
  ('Stefan Knecht', 'mail@knechtgarten.ch', 'Geschaeftsfuehrer / Inhaber', 1),
  ('Pascal Wuethrich', 'pascal.wuethrich@knechtgarten.ch', 'Eidg. dipl. Gartenbautechniker | Gartenplaner | Beratung', 2),
  ('Benjamin Habegger (Benu)', 'bau@knechtgarten.ch', 'Projektleiter Gartenbau', 3),
  ('Fabian Oberholzer', 'fabian.oberholzer@knechtgarten.ch', 'Projektleiter Gartenbau', 4);

-- ----------------------------------------------------------------------------
-- 4. Mail-Vorlagen: Antworten
-- ----------------------------------------------------------------------------

-- 4a. Personalbewerbung (EIN Eintrag mit Rueckfrage statt zwei Sonderfaellen)
with v as (
  insert into mailassistent_vorlage (richtung, titel, typ, frage, wann_trifft_zu, reihenfolge)
  values (
    'antworten',
    'Personalbewerbung',
    'rueckfrage',
    'Ist das Dossier fachlich qualifiziert? (Landschaftsgaertner EFZ im Lebenslauf vorhanden, Dossier ordentlich und sprachlich korrekt, Berufserfahrung passt zum Gartenbau)',
    'Eine Bewerbung / ein Bewerbungsdossier fuer eine Stelle geht ein.',
    1
  )
  returning id
)
insert into mailassistent_vorlage_antwort (vorlage_id, label, inhalt, reihenfolge)
select id, x.label, x.inhalt, x.reihenfolge from v, (values
  ('Qualifiziert - Einladen', 'Guten Tag

Vielen Dank fuer Ihre Bewerbung und Ihr Interesse an unserem Betrieb.

Ihr Dossier hat uns angesprochen. Wir moechten Sie gerne zu einem persoenlichen Gespraech bei uns einladen.

Von unserer Seite sind folgende Termine moeglich:

[Datum, Uhrzeit]
[Datum, Uhrzeit]

Teilen Sie uns gerne mit, welcher Termin fuer Sie am besten passt.

Wir freuen uns, Sie persoenlich kennenzulernen.

Freundliche Gruesse', 1),
  ('Unqualifiziert - Absagen', 'Guten Tag

Vielen Dank fuer Ihre Bewerbung und Ihr Interesse an unserem Betrieb.

Wir haben Ihre Unterlagen geprueft. Leider koennen wir Ihre Bewerbung nicht beruecksichtigen.

Wir wuenschen Ihnen fuer die weitere Suche alles Gute.

Freundliche Gruesse', 2)
) as x(label, inhalt, reihenfolge);

-- 4b. Terminvorschlag vor Ort fuer Diverses bei Bestandeskunden
insert into mailassistent_vorlage (richtung, titel, typ, inhalt, wann_trifft_zu, reihenfolge) values (
  'antworten', 'Terminvorschlag vor Ort (Bestandeskunde, Diverses)', 'einfach',
  'Guten Tag

Vielen Dank fuer Ihre Nachricht.

Am besten sehe ich mir die Situation direkt vor Ort an. So kann ich mir ein genaues Bild machen und wir koennen gemeinsam die naechsten Schritte besprechen.

Von meiner Seite sind folgende Termine moeglich:

[Datum, Uhrzeit]
[Datum, Uhrzeit]

Teilen Sie mir gerne mit, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir gerne einen Alternativtermin vorschlagen.

Bis bald, ich wuensche Ihnen eine gute Zeit.

Herzliche Gruesse aus Heimenschwand',
  'Ein bestehender Kunde meldet sich mit einem konkreten Anliegen (z.B. Nachbesserung, Reklamation, allgemeine Frage zum bestehenden Garten), das am besten vor Ort beurteilt wird - keine neue Kontaktanfrage fuer ein Gartenprojekt.',
  1
);

-- 4c. Terminbestaetigung
insert into mailassistent_vorlage (richtung, titel, typ, inhalt, wann_trifft_zu, reihenfolge) values (
  'antworten', 'Terminbestaetigung', 'einfach',
  'Guten Tag

Herzlichen Dank fuer die Nachricht.

Der Besprechungstermin am [Datum, Uhrzeit] passt gut. Ich habe mir den Termin in meinem Kalender notiert.

Falls sich bei Ihnen noch etwas aendern sollte, melden Sie sich einfach kurz bei mir.

Ich freue mich auf die Besprechung.

Herzliche Gruesse aus Heimenschwand',
  'Der Kunde bestaetigt einen vorgeschlagenen Termin oder schlaegt selbst einen Termin vor, den wir so uebernehmen koennen.',
  2
);

-- ----------------------------------------------------------------------------
-- 5. Sonderfaelle
-- ----------------------------------------------------------------------------

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Kein Ort erkennbar',
  null,
  'Wenn im Mailtext keine PLZ und kein Ortsname erkennbar ist: nicht absagen und keine Distanz-Zone annehmen. Immer nach der Adresse fragen: "Koennten Sie mir noch Ihre Adresse (Strasse, PLZ, Ort) mitteilen? So kann ich pruefen, ob wir in Ihrem Gebiet taetig sind."',
  true, 1
);

with sf_arch as (
  insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
    'Architektenanfragen / Devis-Anfragen',
    'Architekt, Architektin, Architekturbuero, Devis, Submission',
    'Absagen: "Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Leider koennen wir Ihnen fuer dieses Projekt keine Offerte ausarbeiten. Unsere Kapazitaeten sind fuer die naechsten fuenf Monate bereits vollstaendig verplant.

Nach einer ersten Einschaetzung wird Ihr Projekt in diesen Zeitraum fallen.

Unser Schwerpunkt liegt zudem hauptsaechlich bei Gartenprojekten fuer Privatkunden.

Wir wuenschen Ihnen fuer die weitere Planung und Umsetzung gutes Gelingen.

Freundliche Gruesse"',
    true, 2
  ) returning id
)
insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, ist_ausnahme_von, immer_antworten, reihenfolge)
select 'Architekt-Anfrage betrifft Pool oder Naturteich', 'Pool, Naturteich, Schwimmteich', 'Keine Absage - ganz normal wie eine reguere Kontaktanfrage nach Distanzlogik/Zone bearbeiten.', id, true, 3
from sf_arch;

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Werbung, Inserate, Sponsoring',
  'Werbung, Inserat, Sponsoring, Anzeige, Mediapartner',
  'Absagen: "Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an einer Zusammenarbeit.

Unser Budget fuer Werbung und Sponsoring ist fuer dieses Jahr bereits vergeben. Aus diesem Grund koennen wir Ihre Anfrage leider nicht beruecksichtigen.

Wir danken Ihnen fuer Ihr Verstaendnis und wuenschen Ihnen alles Gute.

Freundliche Gruesse"',
  true, 4
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Anfrage fuer Kontonummer zur Rueckerstattung',
  'Rueckerstattung, Kontonummer, IBAN, zurueckerstatten',
  'Bankangaben mitteilen: "Guten Tag

Hier finden Sie die Angaben fuer die Rueckerstattung:

Knecht AG Naturnahe Gaerten
Badhaus 42, 3615 Heimenschwand

IBAN: CH68 8080 8009 0635 6577 8
IID (BC-Nr.): 80808
SWIFT-BIC: RAIFCH22

Vielen Dank fuer die Rueckerstattung.

Freundliche Gruesse"',
  true, 5
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Zahlungsaufschub',
  'Zahlungsaufschub, spaeter bezahlen, Ratenzahlung, mehr Zeit',
  'Grosszuegig gewaehren, ein konkretes neues Datum nennen, kurz halten.',
  true, 6
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Mahnung ohne Rechnung',
  'Mahnung, keine Rechnung erhalten, Rechnung nicht bekommen',
  'Originalrechnung anfordern bzw. eine Kopie der Rechnung anbieten.',
  true, 7
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Rechnungsadresse falsch',
  'Rechnungsadresse falsch, falsche Adresse auf Rechnung',
  'Intern weiterleiten (Buero-Team), dem Kunden eine neue, korrigierte Rechnung ankuendigen.',
  true, 8
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, immer_antworten, reihenfolge) values (
  'Pool/Technik-Problem bei Bestandeskunde',
  'Chlor, Redox, pH-Wert, Skimmer, Schieber, Pumpe, Bewaesserung defekt',
  'Bei Wasserwerten (Chlor/Redox/pH): die genannten Messwerte einordnen und die naechsten Schritte konkret beschreiben. Bei einem technischen Problem (z.B. Schieber, Skimmer) konkret sagen, wer sich wann darum kuemmert (z.B. "Marco schaut heute Morgen kurz vorbei"). Bei einer angepassten Bewaesserung konkret beschreiben, was geaendert wurde.',
  true, 9
);

insert into mailassistent_sonderfall (titel, stichwoerter, verhalten, ist_auffangfall, immer_antworten, reihenfolge) values (
  'Auffangfall - nichts anderes trifft zu',
  null,
  '[PLATZHALTER - bitte pruefen] Freundlich und ruhig antworten, kurz auf das Anliegen eingehen, bei fehlenden Informationen konkret nachfragen. Falls unklar, lieber zwei Antwortvarianten formulieren als raten (siehe Schreibstil-Regel "Unsicherheit bei der Antwort").',
  true, true, 99
);

-- ----------------------------------------------------------------------------
-- 6. Distanzlogik - gemeinsame Einstellungen
-- ----------------------------------------------------------------------------
update mailassistent_distanzlogik_meta set
  wann_anwenden = 'Eine Erstanfrage eines (potenziellen) Kunden zu einem NEUEN Gartenprojekt (Wassergarten/Pool/Naturteich, Terrasse, allgemeine Gartengestaltung, einzelne Bauteile wie Belag/Holzdeck/Rasen, oder Reinigungs-/Pflegearbeiten), bei der die Fahrdistanz zum Kunden ueber die weitere Vorgehensweise entscheidet.
Nicht anwenden bei: Architekten-/Devis-Anfragen (ausser es geht um Pool/Naturteich - siehe Sonderfall-Ausnahme), Werbe-/Sponsoring-Anfragen, Personalbewerbungen, Zahlungsfragen, oder technischen Problemen/Nachbesserungen bei Bestandeskunden (dort direkt einen Vor-Ort-Termin anbieten statt Distanzlogik).

Zusaetzliche Rueckfragen bei einer allgemeinen Anfrage ohne klaren Projektbezug (falls hilfreich, zusaetzlich zur Distanzlogik-Antwort stellen): Wie sind Sie auf uns aufmerksam geworden? Gibt es einen zwingenden Fertigstellungstermin? Haben Sie bereits Inspiration oder Beratung erhalten? Wird eine genaue Offerte gewuenscht oder erst eine Groessenordnung? Bei Terrasse: einzelne Gefaesse oder komplette Neugestaltung? Hinweis: eine Gartenplanung kostet je nach Umfang CHF 1''500 bis 2''500, davon werden 50% bei einer Umsetzung durch uns zurueckerstattet.',
  partner_umkreis_minuten = 35
where true;

-- ----------------------------------------------------------------------------
-- 7. Distanzlogik - Projekttypen + Stufen
-- ----------------------------------------------------------------------------

-- 7a. Wassergarten (Pool/Schwimmteich/Naturteich/Badebrunnen)
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Wassergarten', 'Pool, Schwimmteich, Naturteich, Badebrunnen, Gartenplanung mit Wasserelement', 1)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Am besten sehe ich mir die Situation direkt vor Ort an. So kann ich mir ein genaues Bild machen, Ihre Wuensche aufnehmen und die Gegebenheiten vor Ort beruecksichtigen.

Von meiner Seite sind folgende Termine moeglich:

[Datum, Uhrzeit]
[Datum, Uhrzeit]

Teilen Sie mir gerne mit, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir einen Alternativtermin vorschlagen.

Bitte geben Sie mir noch die genaue Adresse mit Strasse und Ort an.

Ich freue mich, Sie persoenlich kennenzulernen.

Freundliche Gruesse', false, 1),
  (60, 'Guten Tag [Name]

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung bieten wir fuer den ersten Schritt folgende Moeglichkeiten an:

1. Anhand von Fotos: Mit Fotos und einigen Angaben zur Situation koennen wir uns ein gutes Bild machen und eine erste Kostenschaetzung erstellen. Senden Sie uns dazu bitte einige Fotos, eine kurze Beschreibung Ihrer Wuensche sowie die ungefaehren Masse des Bereichs.

2. Besprechung bei uns in Heimenschwand: Sie koennen uns Fotos und vorhandene Unterlagen vorgaengig per Mail zusenden oder zur Besprechung mitbringen. Bei der Besprechung nehmen wir uns Zeit fuer Ihre Fragen, Wuensche und die weitere Vorgehensweise. Zudem stehen die verschiedenen Materialien und Muster direkt vor Ort zur Verfuegung. Von unserer Seite sind folgende Termine moeglich: [Datum, Uhrzeit] / [Datum, Uhrzeit]

3. Planungsauftrag mit Besichtigung vor Ort: Bei umfangreicheren Gartenprojekten koennen wir direkt mit einem Planungsauftrag starten. Die Kosten dafuer liegen je nach Umfang zwischen CHF 1''500 und 2''500. Bei einer anschliessenden Umsetzung durch uns wird die Haelfte davon angerechnet. Wenn dieser Weg fuer Sie passt, kommen wir gerne fuer den ersten Termin bei Ihnen vor Ort vorbei.

Teilen Sie uns gerne mit, welche der drei Varianten fuer Sie am besten ist. Bei Fragen oder Unklarheiten koennen wir gerne telefonieren.

Freundliche Gruesse', false, 2),
  (80, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung entstehen zusaetzliche Fahrzeiten und Kosten, die wir von Anfang an einplanen.

Bei kleineren Projekten mit einer Arbeitsdauer von ungefaehr einer Woche liegen die zusaetzlichen Fahr- und Transportkosten erfahrungsgemaess bei rund CHF 2''000 bis 3''000.

Bei umfangreicheren Gartenprojekten wie einer kompletten Gartengestaltung oder einem Pool liegen die zusaetzlichen Kosten bei rund CHF 15''000 bis 20''000.

Bei weiter entfernten Projekten achten wir besonders auf eine gute Planung. Daher starten wir in solchen Faellen jeweils mit einer Gartenplanung. Die Kosten dafuer liegen je nach Umfang bei rund CHF 2''000. Bei einer anschliessenden Umsetzung durch uns wird die Haelfte davon angerechnet.

Dafuer kommen wir bei Ihnen vor Ort vorbei, besprechen Ihre Wuensche und nehmen die Situation vor Ort auf. Anschliessend erarbeiten wir die passende Loesung fuer Ihren Garten.

Wenn dieser Rahmen fuer Sie passt, geben Sie uns gerne Bescheid. Anschliessend vereinbaren wir den Termin fuer die Planung.

Bei Fragen oder Unklarheiten koennen wir gerne telefonieren.

Freundliche Gruesse', false, 3),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 4)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7b. Terrasse (gleiche Zonen/Texte wie Wassergarten, Original-Doc fasste beide als "Typ A" zusammen)
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Terrasse', 'Terrassenprojekte, Terrassengestaltung', 2)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Am besten sehe ich mir die Situation direkt vor Ort an. So kann ich mir ein genaues Bild machen, Ihre Wuensche aufnehmen und die Gegebenheiten vor Ort beruecksichtigen.

Von meiner Seite sind folgende Termine moeglich:

[Datum, Uhrzeit]
[Datum, Uhrzeit]

Teilen Sie mir gerne mit, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir einen Alternativtermin vorschlagen.

Bitte geben Sie mir noch die genaue Adresse mit Strasse und Ort an.

Ich freue mich, Sie persoenlich kennenzulernen.

Freundliche Gruesse', false, 1),
  (60, 'Guten Tag [Name]

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung bieten wir fuer den ersten Schritt folgende Moeglichkeiten an:

1. Anhand von Fotos: Mit Fotos und einigen Angaben zur Situation koennen wir uns ein gutes Bild machen und eine erste Kostenschaetzung erstellen. Senden Sie uns dazu bitte einige Fotos, eine kurze Beschreibung Ihrer Wuensche sowie die ungefaehren Masse des Bereichs.

2. Besprechung bei uns in Heimenschwand: Sie koennen uns Fotos und vorhandene Unterlagen vorgaengig per Mail zusenden oder zur Besprechung mitbringen. Bei der Besprechung nehmen wir uns Zeit fuer Ihre Fragen, Wuensche und die weitere Vorgehensweise. Zudem stehen die verschiedenen Materialien und Muster direkt vor Ort zur Verfuegung. Von unserer Seite sind folgende Termine moeglich: [Datum, Uhrzeit] / [Datum, Uhrzeit]

3. Planungsauftrag mit Besichtigung vor Ort: Bei umfangreicheren Gartenprojekten koennen wir direkt mit einem Planungsauftrag starten. Die Kosten dafuer liegen je nach Umfang zwischen CHF 1''500 und 2''500. Bei einer anschliessenden Umsetzung durch uns wird die Haelfte davon angerechnet. Wenn dieser Weg fuer Sie passt, kommen wir gerne fuer den ersten Termin bei Ihnen vor Ort vorbei.

Teilen Sie uns gerne mit, welche der drei Varianten fuer Sie am besten ist. Bei Fragen oder Unklarheiten koennen wir gerne telefonieren.

Freundliche Gruesse', false, 2),
  (80, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung entstehen zusaetzliche Fahrzeiten und Kosten, die wir von Anfang an einplanen.

Bei kleineren Projekten mit einer Arbeitsdauer von ungefaehr einer Woche liegen die zusaetzlichen Fahr- und Transportkosten erfahrungsgemaess bei rund CHF 2''000 bis 3''000.

Bei umfangreicheren Gartenprojekten liegen die zusaetzlichen Kosten bei rund CHF 15''000 bis 20''000.

Bei weiter entfernten Projekten achten wir besonders auf eine gute Planung. Daher starten wir in solchen Faellen jeweils mit einer Gartenplanung. Die Kosten dafuer liegen je nach Umfang bei rund CHF 2''000. Bei einer anschliessenden Umsetzung durch uns wird die Haelfte davon angerechnet.

Dafuer kommen wir bei Ihnen vor Ort vorbei, besprechen Ihre Wuensche und nehmen die Situation vor Ort auf. Anschliessend erarbeiten wir die passende Loesung.

Wenn dieser Rahmen fuer Sie passt, geben Sie uns gerne Bescheid. Anschliessend vereinbaren wir den Termin fuer die Planung.

Bei Fragen oder Unklarheiten koennen wir gerne telefonieren.

Freundliche Gruesse', false, 3),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 4)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7c. Allgemein (allgemeine Gartenanlagen/-gestaltung, Bepflanzung, Bewaesserung)
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Allgemein', 'Allgemeine Gartenanlagen, Gartengestaltung, Bepflanzung, Bewaesserungsanlage', 3)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (30, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Am besten sehe ich mir die Situation direkt vor Ort an. So kann ich mir ein genaues Bild machen, Ihre Wuensche aufnehmen und die Gegebenheiten vor Ort beruecksichtigen.

Von meiner Seite sind folgende Termine moeglich:

[Datum, Uhrzeit]
[Datum, Uhrzeit]

Teilen Sie mir gerne mit, welcher Termin fuer Sie am besten passt. Sollte keiner der Vorschlaege moeglich sein, koennen Sie mir einen Alternativtermin vorschlagen.

Bitte geben Sie mir noch die genaue Adresse mit Strasse und Ort an.

Ich freue mich, Sie persoenlich kennenzulernen.

Freundliche Gruesse', false, 1),
  (50, 'Guten Tag [Name]

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung bieten wir fuer den ersten Schritt folgende Moeglichkeiten an:

1. Anhand von Fotos: Mit Fotos und einigen Angaben zur Situation koennen wir uns ein gutes Bild machen und eine erste Kostenschaetzung erstellen. Senden Sie uns dazu bitte einige Fotos, eine kurze Beschreibung Ihrer Wuensche sowie die ungefaehren Masse des Bereichs.

2. Besprechung bei uns in Heimenschwand: Sie koennen uns Fotos und vorhandene Unterlagen vorgaengig per Mail zusenden oder zur Besprechung mitbringen. Von unserer Seite sind folgende Termine moeglich: [Datum, Uhrzeit] / [Datum, Uhrzeit]

3. Planungsauftrag mit Besichtigung vor Ort: Die Kosten dafuer liegen je nach Umfang zwischen CHF 1''500 und 2''500. Bei einer anschliessenden Umsetzung durch uns wird die Haelfte davon angerechnet.

Teilen Sie uns gerne mit, welche der drei Varianten fuer Sie am besten ist. Bei Fragen oder Unklarheiten koennen wir gerne telefonieren.

Freundliche Gruesse', false, 2),
  (70, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Ihr Standort liegt rund [X Minuten] von uns entfernt. Bei dieser Entfernung entstehen zusaetzliche Fahrzeiten und Kosten, die wir von Anfang an einplanen.

Bei kleineren Projekten liegen die zusaetzlichen Fahr- und Transportkosten erfahrungsgemaess bei rund CHF 2''000 bis 3''000, bei umfangreicheren Projekten bei rund CHF 15''000 bis 20''000.

Bei weiter entfernten Projekten starten wir darum jeweils mit einer Gartenplanung (rund CHF 2''000, bei Umsetzung durch uns wird die Haelfte angerechnet). Dafuer kommen wir bei Ihnen vor Ort vorbei und nehmen die Situation auf.

Wenn dieser Rahmen fuer Sie passt, geben Sie uns gerne Bescheid.

Freundliche Gruesse', false, 3),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 4)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7d. Bauteile (Holzdeck, Rasen, Belag als Einzelbauteil)
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Bauteile', 'Einzelne Bauteile wie Holzdeck, Rasen, Belag', 4)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

So wie ich Ihre Anfrage einschaetze, koennen wir die Arbeiten gut anhand von Fotos beurteilen. Fuer eine erste Kostenschaetzung benoetigen wir noch ein paar Angaben zur Situation.

Senden Sie uns dazu bitte einige Fotos sowie die ungefaehren Masse des Bereichs. Hilfreich ist zudem eine kurze Beschreibung, was Sie gerne machen moechten und an welcher Stelle.

Anschliessend melden wir uns mit einer Offerte bei Ihnen. Wenn diese fuer Sie passt, kommen wir gerne fuer die Detailbesprechung vor Ort vorbei.

Freundliche Gruesse', false, 1),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 2)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7e. Poolreinigung
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Poolreinigung', 'Reinigung von Pools', 5)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Eine Kostenschaetzung fuer die Poolreinigung koennen wir gut anhand von Fotos und einigen Angaben erstellen.

Senden Sie uns dazu bitte einige Fotos vom Pool sowie Angaben zur Groesse, zum aktuellen Zustand und zur letzten Reinigung.

Anschliessend melden wir uns gerne mit einer Einschaetzung der Kosten bei Ihnen.

Freundliche Gruesse', false, 1),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 2)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7f. Teichreinigung
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Teichreinigung', 'Reinigung von Schwimmteichen/Teichen', 6)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Eine Kostenschaetzung fuer die Reinigung koennen wir gut anhand von Fotos und einigen Angaben erstellen.

Senden Sie uns dazu bitte einige Fotos von Ihrem Schwimmteich sowie Angaben zur Groesse, Tiefe, zum aktuellen Zustand und zur letzten Reinigung.

Anschliessend melden wir uns gerne mit einer Einschaetzung der Kosten bei Ihnen.

Freundliche Gruesse', false, 1),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 2)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7g. Belagreinigung
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Belagreinigung', 'Reinigung von Belaegen/Platten', 7)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Eine Kostenschaetzung fuer die Belagreinigung koennen wir gut anhand von Fotos und einigen Angaben erstellen.

Senden Sie uns dazu bitte einige Fotos sowie Angaben zur ungefaehren Flaeche, zum Material und zum aktuellen Zustand.

Anschliessend melden wir uns gerne mit einer Einschaetzung der Kosten bei Ihnen.

Freundliche Gruesse', false, 1),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 2)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- 7h. Gartenpflege
with pt as (
  insert into mailassistent_distanz_projekttyp (titel, beschreibung, reihenfolge) values
    ('Gartenpflege', 'Gartenpflege, Unterhalt', 8)
  returning id
)
insert into mailassistent_distanz_stufe (projekttyp_id, bis_minuten, vorlage_text, ist_partner_logik, reihenfolge)
select id, x.bis_minuten, x.vorlage_text, x.ist_partner_logik, x.reihenfolge from pt, (values
  (40, 'Guten Tag

Vielen Dank fuer Ihre Anfrage und Ihr Interesse an unserer Arbeit.

Eine Kostenschaetzung fuer die Gartenpflege koennen wir gut anhand von Fotos und einigen Angaben erstellen.

Senden Sie uns dazu bitte einige Fotos der aktuellen Situation sowie Angaben zur ungefaehren Groesse und zu den gewuenschten Pflegearbeiten.

Anschliessend melden wir uns gerne mit einer Einschaetzung der Kosten bei Ihnen.

Freundliche Gruesse', false, 1),
  (null, '(Partnerlogik - Text wird automatisch anhand des naechstgelegenen Partnerbetriebs generiert, dieses Feld wird dabei nicht verwendet)', true, 2)
) as x(bis_minuten, vorlage_text, ist_partner_logik, reihenfolge);

-- ----------------------------------------------------------------------------
-- 8. Partnerbetriebe ("Aus Leidenschaft"-Gruppe)
-- Hinweis: die Tabelle hat kein eigenes Telefon-/Website-Feld - darum hier
-- mit ins Adressfeld gepackt, damit die KI diese Angaben kennt.
-- ----------------------------------------------------------------------------
insert into mailassistent_partnerbetrieb (name, adresse, reihenfolge) values
  ('Gaerten und mehr AG', 'Lerchenfeld 9, 9601 Luetisburg Station - Tel. 071 931 20 88 - info@gaertenundmehr.ch - gaertenundmehr.ch', 1),
  ('Ihre Gartenwelt AG', 'Gruenaustrasse 24, 5712 Beinwil am See - Tel. 062 771 00 95 - info@ihregartenwelt.ch - ihregartenwelt.ch', 2),
  ('Wetzel Gaerten', 'Mellingerstrasse 13, 5413 Birmenstorf - Tel. 056 225 17 03 - info@wetzelgartenbau.ch - wetzelgartenbau.ch', 3);

-- ----------------------------------------------------------------------------
-- 9. Nachbessern-Buttons [PLATZHALTER - stand nicht im Doc, eigene Vorschlaege]
-- ----------------------------------------------------------------------------
insert into mailassistent_nachbessern_button (titel, anweisung, reihenfolge) values
  ('Kuerzer', 'Faelle den Text kuerzer, nur das Wichtigste behalten.', 1),
  ('Foermlicher', 'Formuliere den Text etwas foermlicher/zurueckhaltender.', 2),
  ('Anderen Termin vorschlagen', 'Schlage andere Termine vor statt der aktuellen.', 3),
  ('Direkter', 'Formuliere direkter und konkreter, weniger Umschreibungen.', 4);
