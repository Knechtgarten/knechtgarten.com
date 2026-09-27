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
// - [data-testid="tile-list-tile"] = eine Ergebnis-Kachel, mit
//   data-testid-doc-id = eindeutige Dokument-ID (Teil der Detail-URL
//   https://app.peax.ch/inbox/search/<doc-id>, bestaetigt durch echten Test).
// - [data-testid="tile-title"] = Titel/Referenznummer.
// - .details .labels .label / .details .values .value = Datumsfelder
//   paarweise (z.B. "Eingang"/"10.09.2026").
// - .amount = Betrag, .tile-status = Status (z.B. "Bezahlt").
// - .tile-background img = Vorschaubild-URL.
// ============================================================================

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
    // Kurze Wartezeit, damit Angular die Ergebnisliste nach dem Navigieren
    // fertig gerendert hat, bevor wir auslesen.
    setTimeout(() => {
      sendResponse({ ergebnisse: liesErgebnislisteAus() });
    }, 1500);
    return true; // asynchrone Antwort
  }
});
