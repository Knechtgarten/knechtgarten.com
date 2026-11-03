/* kg-rechte.js – Katalog für «Gruppen & Rechte» (Verwaltung).
   Tools > Bereiche (Unterseiten). Normale Bereiche haben Anzeigen / Erstellen / Bearbeiten / Löschen
   (K = Keine, E = Eigene, G = Gruppe, A = Alle; Erstellen J/N), Schalter-Bereiche nur J/N (Aktion 'an').
   Die Werte stehen in der Tabelle recht_eintrag, pro Gruppe (recht_gruppe). Fehlt ein Eintrag, gilt «Keine».
   Neuer Bereich: hier eintragen – die Verwaltung zeigt ihn sofort, Werte sind bis zum Setzen «Keine». */
(function(){
  const B = (k, n, h) => ({ k, n, h: h || '' });
  const S = (k, n, h) => ({ k, n, h: h || '', schalter: true });
  window.KG = window.KG || {};
  KG.rechteKatalog = [
    { k: 'offerten', n: 'Offertentool', icon: 'offerten', bereiche: [
      B('offerten', 'Offerten', 'Eingabe und Abschluss'),
      B('kunden', 'Kunden', 'Kundenliste, Easybill-Verknüpfung'),
      B('artikel', 'Artikelstamm & Preise', 'inkl. Lieferanten-Abgleich'),
      B('vorlagen', 'Vorlagen & Formeln', 'Tool B'),
      S('einstellungen', 'Einstellungen', 'Stundensätze, Fahrzeit, Margen'),
      S('easybill', 'Export nach Easybill', 'Offerte als Angebot übertragen') ] },
    { k: 'pend', n: 'Pendenzen', icon: 'pend', bereiche: [
      B('eigenes', 'Eigenes Board', 'Mein Board, Sammelbox'),
      B('buero', 'Büro-Board'),
      B('offerten', 'Offerten-Board', 'Meine Offerten / Alle Offerten'),
      S('listen', 'Listen & Pendenzenarten verwalten') ] },
    { k: 'plan', n: 'Einsatzplaner', icon: 'plan', bereiche: [
      B('einsaetze', 'Einsätze', 'Eigene = eigene Zeile + Titelzeile der Gruppe, Gruppe = alle Zeilen der Planer-Gruppe'),
      B('abwesenheit', 'Abwesenheiten & Ferien'),
      S('einstellungen', 'Planer-Einstellungen', 'Personen, Fahrzeuge, Feiertage') ] },
    { k: 'pflege', n: 'Pflege & Service', icon: 'pflege', bereiche: [
      B('kunden', 'Pflegekunden'),
      B('jahresplan', 'Einsätze (Handy-Ansicht)'),
      B('kategorien', 'Kategorien') ] },
    { k: 'wissen', n: 'Nachschlagewerk & Maschinen', icon: 'wissen', bereiche: [
      B('eintraege', 'Einträge', 'Maschinen, Produkte, Wissen'),
      B('service', 'Maschinen-Service', 'Service erfassen und abhaken') ] },
    { k: 'werkzeuge', n: 'Werkzeuge', icon: 'werkzeuge', bereiche: [
      S('pool_chlor', 'Pool › Stosschlorung'),
      S('pool_salz', 'Pool › Salzzugabe'),
      S('pool_alk', 'Pool › Alkalinität'),
      S('pool_afm', 'Pool › AFM Filterbefüllung'),
      S('pool_volumen', 'Pool › Pool-Volumen'),
      S('bau_diagonale', 'Bau › Rechter Winkel'),
      S('bau_kies', 'Bau › Kies-Gewicht'),
      S('bau_schalit', 'Bau › Beton für Schalungssteine'),
      S('pflege_spritz', 'Pflege › Spritzmittel'),
      S('spritzmittel_pflegen', 'Spritzmittel-Liste bearbeiten', 'Produkte und Dosierungen ändern'),
      S('allg_volumen', 'Allgemein › Volumen', 'mehrere Teile zusammenzählen'),
      S('allg_gefaelle', 'Allgemein › Gefälle') ] },
    { k: 'doku', n: 'Doku-Tools', icon: 'doku', bereiche: [
      S('briefe', 'Briefe erstellen', 'alle Ordner; ohne diesen Schalter nur Ordner «für alle» (z. B. Mitarbeiter: GAV, Reglement)'),
      S('vorlagen', 'Vorlagen bearbeiten', 'Brieftexte, Reglement, PDFs hochladen, Ordner verwalten') ] },
    { k: 'mail', n: 'Mailassistent', icon: 'verw', bereiche: [
      B('entwuerfe', 'Mail-Entwürfe'),
      B('wissen', 'Wissensstruktur & Vorlagen') ] },
    { k: 'verw', n: 'Verwaltung', icon: 'verw', bereiche: [
      B('personen', 'Personen', 'Eigene = nur das eigene Stammblatt'),
      S('personalien', 'Personalien sehen', 'Adresse, Geburtsdatum, Notfallkontakt'),
      B('infos', 'Infos an Mitarbeitende', 'Anzeigen = Liste und «gelesen von», Erstellen = Info senden (Startseite, Verwaltung)'),
      S('rechte', 'Gruppen & Rechte ändern', 'sonst nur Administrator') ] }
  ];
  KG.rechteStufen = [['K', 'Keine'], ['E', 'Eigene'], ['G', 'Gruppe'], ['A', 'Alle']];
})();
