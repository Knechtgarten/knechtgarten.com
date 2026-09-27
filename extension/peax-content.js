// ============================================================================
// Content-Script fuer PEAX (app.peax.ch).
//
// PEAX hat keine fuer uns bezahlbare API (offizielle Anbindung wurde mit
// CHF 7'500.- offeriert, vom Nutzer abgelehnt) - deshalb liest dieses Skript
// die ohnehin im Browser eingeloggte PEAX-Seite direkt aus (aehnliches
// Prinzip wie beim Mail-Assistenten in Gmail), statt eine echte API
// anzusprechen. Ergebnisse werden ans Seitenpanel geschickt und dort im
// gleichen Layout wie Drive/Gmail-Treffer angezeigt - allerdings ohne
// KI-Bewertung, da hier keine KI etwas beurteilt (1:1-Uebernahme von PEAX'
// eigener Trefferliste).
//
// Stabile Kennzeichnungen, auf die sich dieses Skript verlaesst (Stand
// 2026-09-27, kann bei einem PEAX-Layout-Wechsel brechen - siehe
// Projekt-Notiz zur Risikoeinschaetzung):
// - [data-testid="search-input"] = PEAX' eigenes Suchfeld (Angular-
//   Autovervollstaendigung: Tippen zeigt ein Dropdown mit Vorschlaegen,
//   Enter OHNE Auswahl loest trotzdem die volle Suche aus - genau das
//   simuliert dieses Skript, bestaetigt durch echten Test 2026-09-27). Die
//   Adresse aendert sich dabei NICHT (kein URL-Parameter moeglich).
// - [data-testid="tile-list-tile"] = eine Ergebnis-Kachel, mit
//   data-testid-doc-id = eindeutige Dokument-ID (Teil der Detail-URL
//   https://app.peax.ch/inbox/search/<doc-id>, bestaetigt durch echten Test).
// - [data-testid="tile-title"] = Titel/Referenznummer.
// - .details .labels .label / .details .values .value = Datumsfelder
//   paarweise (z.B. "Eingang"/"10.09.2026").
// - .amount = Betrag, .tile-status = Status (z.B. "Bezahlt").
// - .tile-background img = Vorschaubild-URL.
// ============================================================================

function warte(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Angular's ReactiveFormsModule hoert auf native "input"-Events, reagiert
// aber NICHT auf eine simple ".value = ..."-Zuweisung, da Angular die
// Aenderung sonst nicht mitbekommt. Deshalb ueber den nativen Property-
// Setter setzen (umgeht etwaige eigene Getter/Setter der Bibliothek) und
// danach das Event manuell auffeuern.
function setzeEingabewert(input, text) {
  const setter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  setter.call(input, text);
  input.dispatchEvent(new Event('input', { bubbles: true }));
}

function feuereEnter(input) {
  const optionen = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true };
  input.dispatchEvent(new KeyboardEvent('keydown', optionen));
  input.dispatchEvent(new KeyboardEvent('keyup', optionen));
}

async function fuehreSucheAus(begriff) {
  const feld = document.querySelector('[data-testid="search-input"]');
  if (!feld) return false;
  feld.focus();
  setzeEingabewert(feld, begriff);
  // Kurze Pause, damit Angular das Autovervollstaendigungs-Dropdown aufbaut,
  // bevor Enter gedrueckt wird (bestaetigt durch echten Test: Enter ohne
  // Dropdown-Auswahl loest trotzdem die volle Suche aus).
  await warte(500);
  feuereEnter(feld);
  return true;
}

function liesKachelAus(tile) {
  const docId = tile.getAttribute('data-testid-doc-id') || '';
  const titel = tile.querySelector('[data-testid="tile-title"]')?.textContent.trim() || '(ohne Titel)';

  const labels = [...tile.querySelectorAll('.details .labels .label')].map((l) => l.textContent.trim());
  const values = [...tile.querySelectorAll('.details .values .value')].map((v) => v.textContent.trim());
  const datum = values[0] || '';
  const weitereDaten = labels.map((l, i) => `${l} ${values[i] || ''}`).filter((_, i) => i > 0);

  const betrag = tile.querySelector('.amount')?.textContent.trim();
  const status = tile.querySelector('.tile-status')?.textContent.trim();
  const vorschauBild = tile.querySelector('.tile-background img')?.src || undefined;

  return {
    quelle: 'peax',
    id: docId,
    titel,
    datum,
    link: docId ? `https://app.peax.ch/inbox/search/${docId}` : location.href,
    vorschauBild,
    dokumentart: status || undefined,
    begruendung: [betrag, ...weitereDaten].filter(Boolean).join(' · '),
  };
}

function liesErgebnislisteAus() {
  return [...document.querySelectorAll('[data-testid="tile-list-tile"]')].map(liesKachelAus);
}

chrome.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.peaxAction === 'suche') {
    (async () => {
      const sucheAusgeloest = await fuehreSucheAus(msg.begriff || '');
      // Wartezeit, bis Angular die (neue) Ergebnisliste fertig gerendert
      // hat, bevor wir auslesen.
      await warte(1500);
      sendResponse({ ergebnisse: liesErgebnislisteAus(), sucheAusgeloest });
    })();
    return true; // asynchrone Antwort
  }
});
