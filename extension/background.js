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
