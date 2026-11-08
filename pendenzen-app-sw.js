// Service Worker der Pendenzen-App: hält die Erfassungsseite auf dem Handy bereit, damit sie auch ohne Empfang startet.
// Immer zuerst frisch aus dem Netz (Updates kommen sofort), ohne Netz aus dem Zwischenspeicher.
// Gemeinsame Skripte (kg-stil.js?v=…) werden ohne Versionsnummer verglichen, damit ein neues ?v= nichts kaputt macht.
const CACHE = 'pendenzen-app-v7';
const PFADE = ['/pendenzen-app.html', '/kg-pw-schutz.js', '/kg-stil.js', '/kg-pendenz.js', '/pendenzen-app-manifest.json', '/knecht-tool-192.png', '/favicon.ico'];
const FREMD = ['https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all([...PFADE, ...FREMD].map(u => c.add(new Request(u, { cache: 'reload' })).catch(() => {}))))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('pendenzen-app-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const r = e.request; if(r.method !== 'GET') return;
  const url = new URL(r.url);
  if(url.hostname.endsWith('supabase.co')) return; // Daten nie zwischenspeichern
  const seite = r.mode === 'navigate', eigen = url.origin === self.location.origin && PFADE.includes(url.pathname), fremd = FREMD.includes(r.url);
  if(!seite && !eigen && !fremd) return;
  const schluessel = seite ? '/pendenzen-app.html' : eigen ? url.pathname : r.url;
  e.respondWith(fetch(r).then(res => { if(res && (res.ok || res.type === 'opaque')){ const kopie = res.clone(); caches.open(CACHE).then(c => c.put(schluessel, kopie)); } return res; })
    .catch(() => caches.match(schluessel)));
});
