// Hintergrund-Skript (Service Worker) - macht bewusst nur eine Sache: das
// Symbol in der Symbolleiste soll das Seitenpanel oeffnen (nicht ein
// klassisches Popup). Alle eigentliche Logik (Google-Login, Suche) lebt in
// sidepanel.js, nicht hier.
chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((err) => console.error('setPanelBehavior fehlgeschlagen:', err));
