// Service Worker der Pendenzen-App: hält die Erfassungsseite auf dem Handy bereit, damit sie auch ohne Empfang startet.
// Seite immer zuerst frisch aus dem Netz (Updates kommen sofort), ohne Netz aus dem Zwischenspeicher.
const CACHE = 'pendenzen-app-v1';
const DATEIEN = ['/pendenzen-app.html', '/kg-pw-schutz.js?v=5', '/kg-stil.js?v=7', '/pendenzen-app-manifest.json', '/pendenzen-app-192.png',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.js'];
self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => Promise.all(DATEIEN.map(u => c.add(new Request(u, { cache: 'reload' })).catch(() => {}))))); self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('pendenzen-app-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  const r = e.request; if(r.method !== 'GET') return;
  const url = new URL(r.url);
  if(url.hostname.endsWith('supabase.co')) return; // Daten nie zwischenspeichern
  const istSeite = r.mode === 'navigate';
  const merken = DATEIEN.some(d => r.url.endsWith(d) || r.url === d) || istSeite;
  if(!merken) return;
  e.respondWith(fetch(r).then(res => { if(res && (res.ok || res.type === 'opaque')){ const kopie = res.clone(); caches.open(CACHE).then(c => c.put(istSeite ? '/pendenzen-app.html' : r, kopie)); } return res; })
    .catch(() => caches.match(istSeite ? '/pendenzen-app.html' : r, { ignoreSearch: istSeite })));
});
