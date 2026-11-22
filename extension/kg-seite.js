// ============================================================================
// Brücke zwischen den Knechtgarten-Tools (knechtgarten.com) und der Erweiterung.
// Die Seite schickt per window.postMessage { kanal:'kg-ext', typ:'anfrage', nr, auftrag, daten },
// hier geht es an den Hintergrund weiter, die Antwort kommt als { kanal:'kg-ext', typ:'antwort', nr, antwort } zurück.
// Erlaubt sind:
//  - PEAX (Waren-Rücksendung): 'suche', 'liste' (alle Rechnungen eines Absenders) und 'pdf'
//  - QR-Bestellung: 'shopBestellen', 'shopTest', 'shopBestaetigungen', 'shopQuittieren'
// Meldungen vom Hintergrund (z. B. Bestätigungsseite im Shop erkannt) gehen als { kanal:'kg-ext', typ:'ereignis', ereignis } an die Seite.
// Am <html> steht data-kg-ext="<Version>", damit die Seite weiss, dass die Erweiterung da ist.
// ============================================================================
(function () {
  document.documentElement.dataset.kgExt = chrome.runtime.getManifest().version;
  const PEAX = ['suche', 'pdf', 'liste'];
  const SHOP = { shopBestellen: 'bestellen', shopTest: 'test', shopBestaetigungen: 'bestaetigungen', shopQuittieren: 'quittieren' };
  window.addEventListener('message', (e) => {
    if (e.source !== window || e.origin !== location.origin) return;
    const d = e.data;
    if (d?.kanal !== 'kg-ext' || d.typ !== 'anfrage') return;
    let msg = null;
    if (PEAX.includes(d.auftrag)) msg = { kg: 'peaxAuftrag', typ: d.auftrag, daten: d.daten };
    else if (SHOP[d.auftrag]) msg = { kg: 'shopAuftrag', typ: SHOP[d.auftrag], daten: d.daten };
    if (!msg) return;
    chrome.runtime.sendMessage(msg, (antwort) => {
      if (chrome.runtime.lastError) antwort = { fehler: 'Erweiterung nicht erreichbar' };
      window.postMessage({ kanal: 'kg-ext', typ: 'antwort', nr: d.nr, antwort }, location.origin);
    });
  });
  chrome.runtime.onMessage.addListener((msg) => {
    if (msg?.kg === 'shopEreignis') window.postMessage({ kanal: 'kg-ext', typ: 'ereignis', ereignis: 'shop-' + msg.typ }, location.origin);
  });
})();
