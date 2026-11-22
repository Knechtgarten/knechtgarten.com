// Hintergrund-Skript (Service Worker):
// 1. Das Symbol in der Symbolleiste oeffnet das Seitenpanel (nicht ein
//    klassisches Popup). Google-Login und Suche leben in sidepanel.js.
// 2. Kuerzel (Kurzinfos aus dem Nachschlagewerk) beim Start, nach dem
//    Google-Login und alle 15 Minuten neu laden. Die Ersetzung selbst macht
//    kuerzel-content.js auf jeder Seite anhand von chrome.storage.local.
importScripts('google-token.js');

chrome.sidePanel
  .setPanelBehavior({ openPanelOnActionClick: true })
  .catch((err) => console.error('setPanelBehavior fehlgeschlagen:', err));

const KUERZEL_ALARM = 'kuerzel-auffrischen';

function richteKuerzelAlarmEin() {
  chrome.alarms.create(KUERZEL_ALARM, { periodInMinutes: 15 });
  ladeKuerzel();
}

chrome.runtime.onInstalled.addListener(richteKuerzelAlarmEin);
chrome.runtime.onStartup.addListener(richteKuerzelAlarmEin);
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === KUERZEL_ALARM) ladeKuerzel();
});

// Zoll in PEAX (peax-zoll.js): Content-Scripts fragen hier nach dem Google-Token,
// weil nur der Hintergrund ihn bei Bedarf erneuern kann.
chrome.runtime.onMessage.addListener((msg, _sender, antwort) => {
  if (msg?.kg !== 'googleToken') return;
  holeGespeichertenToken().then((token) => antwort({ token })).catch(() => antwort({ token: null }));
  return true;
});

// Waren-Rücksendung im Doku-Tool (kg-seite.js auf knechtgarten.com): Rechnung in PEAX suchen bzw.
// als PDF holen. Läuft über einen PEAX-Tab, weil nur dort die Anmeldung gilt. Ist keiner offen,
// wird PEAX im Hintergrund geöffnet und 10 Minuten nach dem letzten Auftrag wieder geschlossen.
let peaxTabEigen = null, peaxZuTimer = null;
const pause = (ms) => new Promise((r) => setTimeout(r, ms));

async function peaxTab() {
  const offen = await chrome.tabs.query({ url: 'https://app.peax.ch/*' });
  const da = offen.find((t) => t.status === 'complete') || offen[0];
  if (da) return da.id;
  const t = await chrome.tabs.create({ url: 'https://app.peax.ch/inbox/mailbox', active: false });
  peaxTabEigen = t.id;
  return t.id;
}

async function peaxAuftrag(typ, daten) {
  const id = await peaxTab();
  clearTimeout(peaxZuTimer);
  if (id === peaxTabEigen) peaxZuTimer = setTimeout(() => { chrome.tabs.remove(id).catch(() => {}); peaxTabEigen = null; }, 10 * 60000);
  // Content-Script im (evtl. noch ladenden) Tab braucht einen Moment
  for (let i = 0; i < 40; i++) {
    try {
      const a = await chrome.tabs.sendMessage(id, { kg: 'peax', typ, daten });
      if (a !== undefined) return a;
    } catch (_) { /* noch nicht bereit */ }
    await pause(1000);
  }
  return { fehler: 'PEAX antwortet nicht' };
}

chrome.runtime.onMessage.addListener((msg, _sender, antwort) => {
  if (msg?.kg !== 'peaxAuftrag' || !['suche', 'pdf', 'liste'].includes(msg.typ)) return;
  peaxAuftrag(msg.typ, msg.daten).then(antwort).catch((e) => antwort({ fehler: String(e?.message || e) }));
  return true;
});

chrome.tabs.onRemoved.addListener((id) => { if (id === peaxTabEigen) { peaxTabEigen = null; clearTimeout(peaxZuTimer); } });
