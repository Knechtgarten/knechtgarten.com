/* kg-rechte.js – Katalog für «Gruppen & Rechte» (Verwaltung).
   Nur einstellen, was sich zwischen Personen unterscheidet. Drei Arten, in allen Tools gleich:
   - S(...)  Schalter Ja/Nein für eine Funktion (Aktion 'an').
   - J(...)  Schalter Ja/Nein für einen ganzen Bereich: setzt die genannten Aktionen auf Alle/Ja bzw. Keine/Nein
             (die Datenbank prüft weiter z. B. «bearbeiten»).
   - B(...)  Auswahl pro Spalte (Sehen / Neu / Bearbeiten / Löschen) mit Keine · Eigene · (Gruppe) · Alle; «Neu» ist ein Schalter.
   Werte in recht_eintrag pro Gruppe (recht_gruppe). Fehlt ein Eintrag, gilt «Keine». Administrator darf immer alles. */
(function(){
  const B = (k, n, h, spalten, gruppe) => ({ k, n, h: h || '', spalten: spalten || ['anzeigen', 'erstellen', 'bearbeiten', 'loeschen'], gruppe: !!gruppe });
  const J = (k, n, h, setzt) => ({ k, n, h: h || '', ja: true, setzt: setzt || ['anzeigen', 'erstellen', 'bearbeiten', 'loeschen'] });
  const S = (k, n, h) => ({ k, n, h: h || '', schalter: true });
  window.KG = window.KG || {};
  KG.rechteKatalog = [
    { k: 'offerten', n: 'Offertentool', icon: 'offerten', bereiche: [
      B('offerten', 'Offerten', 'Eingabe und Abschluss'),
      B('kunden', 'Kunden', 'Kontakte: Kunden erfassen, ändern, löschen', ['erstellen', 'bearbeiten', 'loeschen']),
      J('artikel', 'Artikelstamm & Preise', 'inkl. Lieferanten-Abgleich', ['erstellen', 'bearbeiten', 'loeschen']),
      J('vorlagen', 'Vorlagen bearbeiten', 'Vorlagen & Berechnung: Vorlagen, Preise, Formeln/Felder ändern, Vorauswahlen, Berechnungsregeln; Tool B'),
      S('einstellungen', 'Sonderpositionen & neue Formeln/Felder', 'Sonderpositionen ändern; Eingabefelder und Formeln anlegen oder löschen. Alles andere in Vorlagen & Berechnung geht mit «Vorlagen bearbeiten»'),
      S('easybill', 'Export nach Easybill', 'Offerte als Angebot übertragen') ] },
    { k: 'pend', n: 'Pendenzen', icon: 'pend', bereiche: [
      J('buero', 'Gemeinsame Boards', 'Büro-Board, Poolboard … (wer Mitglied ist)', ['anzeigen']),
      B('offerten', 'Offerten-Board', 'Eigene = nur «Meine Offerten»', ['anzeigen']),
      B('gemeinsam', 'In gemeinsamen Boards löschen', 'Pendenzen endgültig löschen (Archiv)', ['loeschen']),
      S('listen', 'Listen in gemeinsamen Boards verwalten', 'Listen hinzufügen, umbenennen, löschen; Pendenzenarten') ] },
    { k: 'plan', n: 'Einsatzplaner', icon: 'plan', bereiche: [
      B('einsaetze', 'Planen', 'Eigene = eigene Zeile mit offenen Aufträgen, dazu den Vorrat der eigenen Gruppe in die eigene Zeile ziehen. Gruppe = alle Zeilen der Planer-Gruppe', ['bearbeiten'], true),
      B('vorrat', 'Vorrat bearbeiten', 'Einträge im Vorrat erfassen, ändern, löschen. Eigene = selbst erfasste, Gruppe = Vorrat der eigenen Planer-Gruppe. Einplanen geht mit «Planen»', ['bearbeiten'], true),
      B('abwesenheit', 'Abwesenheiten & Ferien', '', ['bearbeiten'], true),
      S('reservieren', 'Anhänger selber reservieren', 'Anhänger mit Haken «selber reservierbar»: Handy › Reservieren und im Planer, nur eigene ändern'),
      S('einstellungen', 'Planer-Einstellungen', 'Personen, Fahrzeuge, Feiertage') ] },
    { k: 'pflege', n: 'Pflege & Service', icon: 'pflege', bereiche: [
      J('kunden', 'Pflegekunden bearbeiten', '', ['erstellen', 'bearbeiten', 'loeschen']),
      J('jahresplan', 'Einsätze abhaken (Handy)', 'Pflege-Handy: Status, Fotos, Dokumente', ['erstellen', 'bearbeiten', 'loeschen']),
      J('kategorien', 'Kategorien bearbeiten', 'Arbeiten, Felder, Regionen', ['erstellen', 'bearbeiten', 'loeschen']) ] },
    { k: 'wissen', n: 'Nachschlagewerk & Maschinen', icon: 'wissen', bereiche: [
      J('eintraege', 'Einträge bearbeiten', 'Maschinen, Produkte, Wissen', ['erstellen', 'bearbeiten', 'loeschen']),
      J('service', 'Maschinen-Service abhaken', 'Service erfassen und abhaken', ['erstellen', 'bearbeiten']) ] },
    { k: 'werkzeuge', n: 'Werkzeuge', icon: 'werkzeuge', bereiche: [
      S('pool_chlor', 'Pool › Stosschlorung'),
      S('pool_salz', 'Pool › Salzzugabe'),
      S('pool_alk', 'Pool › Alkalinität'),
      S('pool_afm', 'Pool › AFM Filterbefüllung'),
      S('pool_volumen', 'Pool › Pool-Volumen'),
      S('bau_diagonale', 'Bau › Rechter Winkel'),
      S('bau_kies', 'Bau › Kies-Gewicht'),
      S('bau_stahl', 'Bau › Stahl'),
      S('bau_schalit', 'Bau › Beton für Schalungssteine'),
      S('pflege_spritz', 'Pflege › Spritzmittel'),
      S('spritzmittel_pflegen', 'Spritzmittel-Liste bearbeiten', 'Produkte und Dosierungen ändern'),
      S('allg_gefaelle', 'Bau › Gefälle') ] },
    { k: 'doku', n: 'Doku-Tools', icon: 'doku', bereiche: [
      S('briefe', 'Briefe erstellen', 'alle Ordner; ohne diesen Schalter nur Ordner «für alle» (z. B. Mitarbeiter: GAV, Reglement)'),
      S('vorlagen', 'Vorlagen bearbeiten', 'Brieftexte, Reglement, PDFs hochladen, Ordner verwalten') ] },
    { k: 'mail', n: 'Mailassistent', icon: 'verw', bereiche: [
      J('entwuerfe', 'Mail-Entwürfe', ''),
      J('wissen', 'Wissensstruktur & Vorlagen bearbeiten', '') ] },
    { k: 'verw', n: 'Verwaltung', icon: 'verw', bereiche: [
      J('infos', 'Infos an Mitarbeitende senden', 'Startseite und Verwaltung, inkl. «gelesen von»', ['anzeigen', 'erstellen']),
      S('personalien', 'Personalien sehen', 'Adresse, Geburtsdatum, Notfallkontakt') ] }
  ];
  KG.rechteStufen = [['K', 'Keine'], ['E', 'Eigene'], ['G', 'Gruppe'], ['A', 'Alle']];
})();
