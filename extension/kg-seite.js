// ============================================================================
// Brücke zwischen den Knechtgarten-Tools (knechtgarten.com) und der Erweiterung.
// Die Seite schickt per window.postMessage { kanal:'kg-ext', typ:'anfrage', nr, auftrag, daten },
// hier geht es an den Hintergrund weiter, die Antwort kommt als { kanal:'kg-ext', typ:'antwort', nr, antwort } zurück.
// Erlaubt sind nur die PEAX-Aufträge der Waren-Rücksendung: 'suche', 'liste' (alle Rechnungen eines Absenders) und 'pdf'.
// Am <html> steht data-kg-ext="<Version>", damit die Seite weiss, dass die Erweiterung da ist.
// ============================================================================
(function () {
  document.documentElement.dataset.kgExt = chrome.runtime.getManifest().version;
  window.addEventListener('message', (e) => {
    if (e.source !== window || e.origin !== location.origin) return;
    const d = e.data;
    if (d?.kanal !== 'kg-ext' || d.typ !== 'anfrage' || !['suche', 'pdf', 'liste'].includes(d.auftrag)) return;
    chrome.runtime.sendMessage({ kg: 'peaxAuftrag', typ: d.auftrag, daten: d.daten }, (antwort) => {
      if (chrome.runtime.lastError) antwort = { fehler: 'Erweiterung nicht erreichbar' };
      window.postMessage({ kanal: 'kg-ext', typ: 'antwort', nr: d.nr, antwort }, location.origin);
    });
  });
})();
