// ============================================================================
// Dokumenten-Suche - Seitenpanel-Logik.
//
// Ablauf: Google-Login per chrome.identity.launchWebAuthFlow mit Authorization-
// Code + PKCE (kein Client-Secret im Erweiterungscode - der Code-Tausch und
// die spaetere Token-Erneuerung laufen ueber die Edge Function, die das
// Secret serverseitig haelt). Ergebnis ist ein kurzlebiger Access-Token PLUS
// ein langlebiger Refresh-Token, der in chrome.storage.local zwischengespeichert
// wird - laeuft der Access-Token ab, wird er im Hintergrund per Refresh-Token
// automatisch erneuert, ohne dass sich die/der Mitarbeitende erneut mit
// Google verbinden muss (fruehere Version nutzte einen Implicit-Grant-Token
// ohne Erneuerungsmoeglichkeit, der nach ~1h eine erneute manuelle Anmeldung
// erzwang). Die eigentliche Suche laeuft ueber dieselbe Supabase Edge
// Function "dokumenten-suche" (Phase 3: Claude orchestriert die Google-Suche
// selbst und bewertet die Treffer).
//
// PEAX ist bewusst NICHT Teil der gemeinsamen Suche (kein API-Zugang) -
// der PEAX-Chip oeffnet stattdessen direkt PEAX' eigene Suchseite in einem
// neuen Tab. Die genaue URL/Query-Parameter von PEAX' Suchseite sind noch
// nicht bestaetigt (siehe TODO unten) - vorerst wird nur die Suchseite ohne
// vorausgefuellten Begriff geoeffnet.
// ============================================================================

const GOOGLE_CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const GOOGLE_SCOPES = [
  'https://www.googleapis.com/auth/drive.readonly',
  'https://www.googleapis.com/auth/gmail.readonly',
];
const EDGE_FUNCTION_URL = 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/dokumenten-suche';
const SUPABASE_ANON_KEY = 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P';

const $ = (id) => document.getElementById(id);

// ---------------------------------------------------------------------------
// Google-Login (Authorization Code + PKCE + Refresh-Token)
// ---------------------------------------------------------------------------
function base64UrlVonBytes(bytes) {
  let bin = '';
  bytes.forEach((b) => { bin += String.fromCharCode(b); });
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function zufallsCodeVerifier() {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64UrlVonBytes(bytes);
}
async function codeChallengeAus(verifier) {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier));
  return base64UrlVonBytes(new Uint8Array(hash));
}

function baueAuthUrl(redirectUri, codeChallenge) {
  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    response_type: 'code',
    redirect_uri: redirectUri,
    scope: GOOGLE_SCOPES.join(' '),
    // access_type=offline + prompt=consent erzwingen, dass Google ueberhaupt
    // einen Refresh-Token ausstellt (sonst nur beim allerersten Consent).
    access_type: 'offline',
    prompt: 'consent',
    code_challenge: codeChallenge,
    code_challenge_method: 'S256',
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
}

function parseCodeAusRedirect(redirectUrl) {
  const code = new URL(redirectUrl).searchParams.get('code');
  if (!code) throw new Error('Kein code in der Antwort von Google.');
  return code;
}

// Speichert Access-Token + Ablaufzeit, behaelt einen vorhandenen Refresh-Token
// bei, falls die aktuelle Antwort (z.B. eine reine Erneuerung) keinen neuen
// mitliefert - Google gibt den Refresh-Token normalerweise nur beim ersten
// Consent zurueck.
async function speichereToken({ accessToken, expiresIn, refreshToken }) {
  const vorhandenes = (await chrome.storage.local.get('googleToken')).googleToken || {};
  await chrome.storage.local.set({
    googleToken: {
      accessToken,
      ablaufZeit: Date.now() + (Number(expiresIn) || 3600) * 1000,
      refreshToken: refreshToken || vorhandenes.refreshToken || null,
    },
  });
}

async function holeGespeichertenToken() {
  const { googleToken } = await chrome.storage.local.get('googleToken');
  if (!googleToken) return null;
  // 60 Sekunden Puffer vor dem eigentlichen Ablauf.
  if (googleToken.ablaufZeit > Date.now() + 60_000) return googleToken.accessToken;
  if (!googleToken.refreshToken) return null;
  // Access-Token abgelaufen, aber Refresh-Token vorhanden: im Hintergrund
  // erneuern statt die/den Mitarbeitende(n) erneut durch die Google-Anmeldung
  // zu schicken.
  try {
    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      body: JSON.stringify({ oauthAction: 'refresh', refreshToken: googleToken.refreshToken }),
    });
    const data = await res.json();
    if (!res.ok || !data.accessToken) throw new Error(data.error || 'Refresh fehlgeschlagen.');
    await speichereToken({ accessToken: data.accessToken, expiresIn: data.expiresIn, refreshToken: googleToken.refreshToken });
    return data.accessToken;
  } catch (e) {
    console.error('Automatische Token-Erneuerung fehlgeschlagen:', e);
    return null;
  }
}

function verbinden() {
  $('connectStatus').textContent = 'Google-Anmeldefenster öffnet sich …';
  $('connectStatus').className = 'status-line';
  verbindenAblauf().catch((e) => {
    $('connectStatus').textContent = 'Fehler: ' + e.message;
    $('connectStatus').className = 'status-line err';
  });
}

async function verbindenAblauf() {
  const redirectUri = chrome.identity.getRedirectURL();
  const codeVerifier = zufallsCodeVerifier();
  const codeChallenge = await codeChallengeAus(codeVerifier);
  const redirectUrl = await new Promise((resolve, reject) => {
    chrome.identity.launchWebAuthFlow({ url: baueAuthUrl(redirectUri, codeChallenge), interactive: true }, (url) => {
      if (chrome.runtime.lastError || !url) reject(new Error(chrome.runtime.lastError?.message || 'abgebrochen'));
      else resolve(url);
    });
  });
  const code = parseCodeAusRedirect(redirectUrl);
  const res = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
    body: JSON.stringify({ oauthAction: 'exchange', code, codeVerifier, redirectUri }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || `Fehler ${res.status}`);
  if (!data.accessToken) throw new Error('Kein accessToken erhalten.');
  await speichereToken(data);
  zeigeSuche();
}

function zeigeSuche() {
  $('connectBox').hidden = true;
  $('searchBox').hidden = false;
  ladeDokumentarten();
}

// ---------------------------------------------------------------------------
// Tabs (Alle/Drive/Gmail/PEAX) - ersetzen die fruehere Quelle-Mehrfachauswahl:
// ein Tab bestimmt sowohl welche Filterfelder sichtbar sind als auch welche
// Quellen die Suche durchsucht. Zusaetzlich wird beim Oeffnen des Panels
// versucht, den passenden Tab automatisch anhand der Adresse des gerade
// aktiven Browser-Tabs vorauszuwaehlen (siehe erkenneUndSetzeTabAusAktivemBrowserTab).
// ---------------------------------------------------------------------------
let aktiverTab = 'alle';
let urlZuordnungListe = [];
let standardTabFallback = 'alle';
// Muss vor setzeAktivenTab() deklariert sein, da der allererste Aufruf
// (setzeAktivenTab('alle') weiter unten) schon beim Laden ausgefuehrt wird.
let letzteErgebnisRohliste = [];

// Fest hinterlegte Standardfaelle - admin-gepflegte Zuordnungen (aus der GET-
// Antwort) werden zuerst geprueft, damit sie diese bei Bedarf ueberschreiben
// koennen.
const HARDCODIERTE_URL_ZUORDNUNG = [
  { urlMuster: 'drive.google.com', tab: 'drive' },
  { urlMuster: 'mail.google.com', tab: 'gmail' },
  { urlMuster: 'app.peax.ch', tab: 'peax' },
];

function ermittleTabFuerUrl(url) {
  if (!url) return standardTabFallback;
  const treffer = urlZuordnungListe.find((z) => url.includes(z.urlMuster))
    || HARDCODIERTE_URL_ZUORDNUNG.find((z) => url.includes(z.urlMuster));
  return treffer ? treffer.tab : standardTabFallback;
}

async function erkenneUndSetzeTabAusAktivemBrowserTab() {
  try {
    const tabs = await new Promise((resolve) => chrome.tabs.query({ active: true, currentWindow: true }, resolve));
    setzeAktivenTab(ermittleTabFuerUrl(tabs?.[0]?.url || ''));
  } catch (e) {
    console.error('Aktiven Browser-Tab erkennen fehlgeschlagen:', e);
  }
}

function setzeAktivenTab(tab) {
  aktiverTab = tab;
  document.querySelectorAll('.tab-bar button[data-tab]').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
  document.querySelectorAll('[data-tab-scope]').forEach((el) => {
    el.hidden = !el.dataset.tabScope.split(' ').includes(tab);
  });
  // Ausgeblendete Mehrfachauswahl-Filter (Dokumentart/Dateiformat) auf "Alle"
  // zuruecksetzen - sonst wuerde eine auf einem anderen Tab getroffene, jetzt
  // unsichtbare Auswahl die Suche hier unbemerkt mitfiltern (z.B. Gmail-Tab:
  // Dateiformat ist ausgeblendet, dort reicht "Anhaenge durchsuchen").
  if ($('dokumentartVorabRow').hidden) $('dokumentartVorabRow').querySelector('.chip')?.click();
  if ($('dateiformatRow').hidden) $('dateiformatRow').querySelector('.chip')?.click();

  // Trefferliste eines anderen Tabs gehoert nicht hierher - sonst blieben
  // z.B. Drive-Ergebnisse sichtbar, wenn man zu PEAX/Gmail wechselt, obwohl
  // dort noch gar nicht gesucht wurde.
  letzteErgebnisRohliste = [];
  $('docList').innerHTML = '';
  $('resultsHeader').hidden = true;
  $('statusLine').textContent = '';
  $('suchschritteBox').hidden = true;
}
document.querySelectorAll('.tab-bar button[data-tab]').forEach((btn) => {
  btn.addEventListener('click', () => setzeAktivenTab(btn.dataset.tab));
});
setzeAktivenTab('alle');

document.querySelectorAll('.seg button[data-genauigkeit]').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.seg button[data-genauigkeit]').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
  });
});

document.querySelectorAll('.seg button[data-runden]').forEach((btn) => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.seg button[data-runden]').forEach((b) => b.classList.remove('active'));
    btn.classList.add('active');
  });
});

// ---------------------------------------------------------------------------
// Zeitraum-Schnellauswahl: fuellt Von/Bis automatisch aus statt manuell im
// Datumspicker zu klicken.
// ---------------------------------------------------------------------------
function alsDatumInput(d) { return d.toISOString().slice(0, 10); }

function setzeZeitraumSchnellauswahl(aktivesBtn) {
  $('btnZeitraum6Wochen').classList.toggle('active', aktivesBtn === 'sechsWochen');
  $('btnZeitraumJahr').classList.toggle('active', aktivesBtn === 'jahr');
}

$('btnZeitraum6Wochen').addEventListener('click', () => {
  const von = new Date();
  von.setDate(von.getDate() - 42);
  $('zeitraumVon').value = alsDatumInput(von);
  $('zeitraumBis').value = '';
  setzeZeitraumSchnellauswahl('sechsWochen');
});
$('btnZeitraumJahr').addEventListener('click', () => {
  const jahresanfang = new Date(new Date().getFullYear(), 0, 1);
  $('zeitraumVon').value = alsDatumInput(jahresanfang);
  $('zeitraumBis').value = '';
  setzeZeitraumSchnellauswahl('jahr');
});
// Manuelle Datumsaenderung: Schnellauswahl-Buttons zeigen dann keinen
// (falschen) aktiven Zustand mehr an.
$('zeitraumVon').addEventListener('input', () => setzeZeitraumSchnellauswahl(null));
$('zeitraumBis').addEventListener('input', () => setzeZeitraumSchnellauswahl(null));

// Standardmaessig "Letzte 6 Wochen" vorausgewaehlt.
$('btnZeitraum6Wochen').click();

$('peaxBtn').addEventListener('click', () => {
  // Manueller Ausweichweg: PEAX' eigene Suchseite direkt oeffnen (z.B. um
  // selbst nachzuschauen, falls das automatische Auslesen mal nichts findet).
  // Kein URL-Parameter moeglich (PEAX' Suche laeuft clientseitig), deshalb
  // muss der Suchbegriff dort von Hand erneut eingetippt werden.
  chrome.tabs.create({ url: 'https://app.peax.ch/inbox/search', active: false });
});

// ---------------------------------------------------------------------------
// Suche
// ---------------------------------------------------------------------------
// An Original-Icons angelehnt (bewusste Ausnahme vom sonst einheitlichen
// Linien-Icon-Stil - Dateityp-Erkennung lebt von den bekannten Farbcodes),
// gleiche SVGs wie im Mockup "Suchpanel".
const FTYPE_ICONS = {
  pdf: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#F7B4AC"/><rect x="5" y="14" width="14" height="6" rx="1" fill="#DB4437"/><text x="12" y="18.6" font-size="5" font-weight="700" fill="#fff" text-anchor="middle" font-family="Arial, sans-serif">PDF</text></svg>',
  docs: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#A4C2F4"/><rect x="7" y="9.5" width="10" height="1.8" rx=".5" fill="#4285F4"/><rect x="7" y="13" width="10" height="1.8" rx=".5" fill="#4285F4"/><rect x="7" y="16.5" width="7" height="1.8" rx=".5" fill="#4285F4"/></svg>',
  sheets: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#A8DAB5"/><rect x="7" y="9.5" width="10" height="7.5" fill="none" stroke="#0F9D58" stroke-width="1.6"/><line x1="7" y1="13.25" x2="17" y2="13.25" stroke="#0F9D58" stroke-width="1.6"/><line x1="12" y1="9.5" x2="12" y2="17" stroke="#0F9D58" stroke-width="1.6"/></svg>',
  mail: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" fill="#EA4335"/><path d="M3 6l9 6.5L21 6" fill="none" stroke="#fff" stroke-width="2"/></svg>',
  bild: '<svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2" fill="#F3E8FD" stroke="#8C6DAB" stroke-width="1.4"/><circle cx="8.5" cy="9.5" r="2" fill="#8C6DAB"/><path d="M4 17l5-5 4 4 3-3 4 4" fill="none" stroke="#8C6DAB" stroke-width="2"/></svg>',
  generic: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#D7D3CE"/></svg>',
  peax: '<svg viewBox="0 0 24 24"><path d="M12 2l8 3v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V5z" fill="#F5C400" stroke="#1E1E1E" stroke-width="1"/></svg>',
};
function ftypeIcon(dateityp, quelle) {
  if (quelle === 'gmail') return FTYPE_ICONS.mail;
  if (quelle === 'peax') return FTYPE_ICONS.peax;
  if (dateityp === 'application/pdf') return FTYPE_ICONS.pdf;
  if (dateityp === 'application/vnd.google-apps.document') return FTYPE_ICONS.docs;
  if (dateityp === 'application/vnd.google-apps.spreadsheet') return FTYPE_ICONS.sheets;
  if (dateityp?.startsWith('image/')) return FTYPE_ICONS.bild;
  return FTYPE_ICONS.generic;
}

const SOURCE_ICONS = {
  drive: '<svg viewBox="0 0 24 24"><path fill="#4285F4" d="M8.5 3h7l7.5 13-3.5 6h-15z"/><path fill="#34A853" d="M4.5 22l3.5-6h15l-3.5 6z"/><path fill="#FBBC05" d="M8.5 3l-4 7 4 6.5 4-6.5z"/></svg>',
  gmail: '<svg viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2" fill="#EA4335"/><path fill="#fff" d="M4 6l8 6 8-6v2l-8 6-8-6z"/></svg>',
  peax: '<svg viewBox="0 0 24 24"><path d="M12 2l8 3v6c0 5-3.5 8.5-8 11-4.5-2.5-8-6-8-11V5z" fill="#F5C400" stroke="#1E1E1E" stroke-width="1"/></svg>',
};
function quelleLabel(quelle) {
  return quelle === 'drive' ? 'Drive' : quelle === 'gmail' ? 'Gmail' : 'PEAX';
}
// PEAX liefert Datum bereits als fertig formatierten Text (z.B. "10.09.2026"),
// Drive/Gmail liefern ein ISO-Datum - deshalb hier je nach Quelle behandeln.
function datumAnzeige(e) {
  return e.quelle === 'peax' ? (e.datum || '') : fmtDatum(e.datum);
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function fmtDatum(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('de-CH');
}

// ---------------------------------------------------------------------------
// Wiederverwendbare Mehrfachauswahl-Chipreihe mit "Alle" (Dokumentart,
// Dateiformat) - leere Auswahl bedeutet "Alle" (keine Einschraenkung).
// ---------------------------------------------------------------------------
function baueMehrfachauswahl(container, optionen) {
  const ausgewaehlt = new Set();
  function render() {
    container.innerHTML = '';
    const alle = document.createElement('span');
    alle.className = 'chip' + (ausgewaehlt.size === 0 ? ' active' : '');
    alle.textContent = 'Alle';
    alle.addEventListener('click', () => { ausgewaehlt.clear(); render(); });
    container.appendChild(alle);
    for (const opt of optionen) {
      const chip = document.createElement('span');
      chip.className = 'chip' + (opt.icon ? ' ftype-chip' : '') + (ausgewaehlt.has(opt.value) ? ' active' : '');
      chip.title = opt.label;
      if (opt.icon) {
        const iconSpan = document.createElement('span');
        iconSpan.className = 'chip-icon';
        iconSpan.innerHTML = opt.icon;
        chip.appendChild(iconSpan);
      } else {
        chip.appendChild(document.createTextNode(opt.label));
      }
      chip.addEventListener('click', () => {
        if (ausgewaehlt.has(opt.value)) ausgewaehlt.delete(opt.value); else ausgewaehlt.add(opt.value);
        render();
      });
      container.appendChild(chip);
    }
  }
  render();
  return { getSelected: () => (ausgewaehlt.size ? [...ausgewaehlt] : undefined) };
}

const dateiformatAuswahl = baueMehrfachauswahl($('dateiformatRow'), [
  { value: 'pdf', label: 'PDF', icon: FTYPE_ICONS.pdf },
  { value: 'docs', label: 'Google Docs', icon: FTYPE_ICONS.docs },
  { value: 'sheets', label: 'Google Sheets', icon: FTYPE_ICONS.sheets },
  { value: 'mail', label: 'Mail', icon: FTYPE_ICONS.mail },
  { value: 'bild', label: 'Bild', icon: FTYPE_ICONS.bild },
]);

let dokumentartAuswahl = { getSelected: () => undefined };
async function ladeDokumentarten() {
  try {
    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'GET',
      headers: { Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
    });
    const data = await res.json();
    const optionen = (data.dokumentarten || []).map((name) => ({ value: name, label: name }));
    dokumentartAuswahl = baueMehrfachauswahl($('dokumentartVorabRow'), optionen);
    $('lieferantenListe').innerHTML = (data.lieferanten || [])
      .map((name) => `<option value="${esc(name)}"></option>`)
      .join('');
    urlZuordnungListe = data.urlZuordnung || [];
    standardTabFallback = data.standardTabFallback || 'alle';
  } catch (e) {
    console.error('Dokumentarten laden fehlgeschlagen:', e);
  } finally {
    // Erst NACH dem Laden der (admin-gepflegten) URL-Zuordnung erkennen, sonst
    // wuerde beim allerersten Panel-Oeffnen noch mit leerer Liste (nur den
    // hartcodierten Standardfaellen) erkannt.
    erkenneUndSetzeTabAusAktivemBrowserTab();
  }
}

let lightboxListe = [];
let lightboxIndex = 0;

function zeichneErgebnisse(ergebnisse) {
  lightboxListe = ergebnisse;
  $('resultsHeader').hidden = false;
  $('resultsCount').textContent = `${ergebnisse.length} Dokument${ergebnisse.length === 1 ? '' : 'e'}`;
  $('docList').innerHTML = '';
  ergebnisse.forEach((e, i) => {
    const row = document.createElement('div');
    row.className = 'doc-row';
    row.innerHTML = `
      <span class="doc-icon">${ftypeIcon(e.dateityp, e.quelle)}</span>
      <span class="doc-main">
        <div class="doc-top-line">
          <div class="doc-title"></div>
          <span class="match-badge"></span>
        </div>
        <div class="doc-meta"></div>
        <div class="doc-begruendung"></div>
      </span>
      ${e.vorschauBild ? `<img class="hover-vorschau" src="${e.vorschauBild}" loading="lazy">` : ''}`;
    const hoverBild = row.querySelector('.hover-vorschau');
    if (hoverBild) hoverBild.onerror = () => hoverBild.remove();
    row.querySelector('.doc-title').textContent = e.titel;
    const badge = row.querySelector('.match-badge');
    if (e.uebereinstimmung) {
      badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hoch' : 'Möglich';
      badge.classList.add(e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
    } else {
      badge.hidden = true;
    }
    row.querySelector('.doc-meta').innerHTML = `<span class="src-icon">${SOURCE_ICONS[e.quelle] || ''}</span>${quelleLabel(e.quelle)} · ${datumAnzeige(e)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
    row.querySelector('.doc-begruendung').textContent = e.begruendung || '';
    row.addEventListener('click', () => openLightbox(i));
    $('docList').appendChild(row);
  });
}

// ---------------------------------------------------------------------------
// Sortierung (Relevanz = Original-Reihenfolge der KI, sonst Datum/Dateityp).
// ---------------------------------------------------------------------------
function sortiereUndZeichne() {
  const modus = $('sortSelect').value;
  let liste = [...letzteErgebnisRohliste];
  if (modus === 'datum-neu') liste.sort((a, b) => new Date(b.datum || 0) - new Date(a.datum || 0));
  else if (modus === 'datum-alt') liste.sort((a, b) => new Date(a.datum || 0) - new Date(b.datum || 0));
  else if (modus === 'dateityp') liste.sort((a, b) => (a.dateityp || a.quelle).localeCompare(b.dateityp || b.quelle));
  zeichneErgebnisse(liste);
}
$('sortSelect').addEventListener('change', sortiereUndZeichne);

// ---------------------------------------------------------------------------
// Vorschau-Lightbox: klicken zeigt Details + Vor/Zurueck statt sofort einen
// neuen Tab zu oeffnen (Muster aus dem Mockup "Suchpanel").
// ---------------------------------------------------------------------------
function openLightbox(i) {
  lightboxIndex = i;
  renderLightbox();
  $('lightbox').classList.add('open');
}
function closeLightbox() { $('lightbox').classList.remove('open'); }
function navLightbox(delta) {
  lightboxIndex = (lightboxIndex + delta + lightboxListe.length) % lightboxListe.length;
  renderLightbox();
}
function renderLightbox() {
  const e = lightboxListe[lightboxIndex];
  if (!e) return;
  $('lbIcon').innerHTML = ftypeIcon(e.dateityp, e.quelle);
  $('lbTitle').textContent = e.titel;
  $('lbMeta').innerHTML = `<span class="src-icon">${SOURCE_ICONS[e.quelle] || ''}</span>${quelleLabel(e.quelle)} · ${datumAnzeige(e)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
  const badge = $('lbMatch');
  if (e.uebereinstimmung) {
    badge.hidden = false;
    badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hohe Übereinstimmung' : 'Mögliche Übereinstimmung';
    badge.className = 'match-badge ' + (e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
  } else {
    badge.hidden = true;
  }
  $('lbBody').textContent = e.begruendung || '';
  $('lbPosition').textContent = `${lightboxIndex + 1} von ${lightboxListe.length}`;
  // Öffnet im Hintergrund (active:false), damit der Tab, in dem gerade
  // weitergearbeitet wird (z.B. Easybill), nicht weggeschnappt wird.
  $('lbOpen').onclick = () => chrome.tabs.create({ url: e.link, active: false });

  const wrap = $('lbVorschauWrap');
  const bild = $('lbVorschauBild');
  const iframe = $('lbVorschauIframe');
  const seitenBox = $('lbVorschauSeiten');
  const schaerferBtn = $('lbPeaxSchaerfer');
  seitenBox.hidden = true;
  seitenBox.innerHTML = '';
  schaerferBtn.hidden = true;
  schaerferBtn.disabled = false;
  schaerferBtn.textContent = 'Scharfe Vorschau laden';

  if (e.quelle === 'drive') {
    // Drive bietet eine offizielle Einbett-Vorschau, die mehrseitige PDFs/Docs
    // per echtem Scrollen anzeigt (statt nur eines statischen Vorschaubilds
    // der ersten Seite) - kein zusaetzlicher API-Aufruf noetig.
    wrap.hidden = false;
    wrap.classList.add('kein-ziehen');
    bild.hidden = true;
    bild.removeAttribute('src');
    iframe.hidden = false;
    iframe.src = `https://drive.google.com/file/d/${e.id}/preview`;
  } else {
    iframe.hidden = true;
    iframe.removeAttribute('src');
    wrap.classList.remove('kein-ziehen');
    bild.hidden = false;
    if (e.vorschauBild) {
      wrap.hidden = false;
      bild.src = e.vorschauBild;
      bild.onerror = () => { wrap.hidden = true; };
    } else {
      wrap.hidden = true;
      bild.removeAttribute('src');
    }
    // PEAX hat keine Einbett-Vorschau wie Drive - stattdessen auf Wunsch
    // (kann einige Sekunden dauern, oeffnet kurz einen Hintergrund-Tab)
    // die echten, scharfen Seiten aus PEAX' eigenem PDF-Betrachter holen.
    if (e.quelle === 'peax') {
      wrap.hidden = false;
      schaerferBtn.hidden = false;
    }
  }
}

// PEAX hat keine per DevTools auffindbare PDF-Datei-Adresse (geprueft
// 2026-09-27) - deshalb wird kurz ein Hintergrund-Tab mit dem echten
// Dokument geoeffnet, PEAX' eigener PDF-Betrachter rendert die Seiten, das
// Content-Script (peax-content.js) liest sie als fertige Bilder aus
// (canvas.toDataURL) und schickt sie zurueck. Kein API-Zugriff noetig, da
// nur gelesen wird, was PEAX selbst schon auf dem Bildschirm zeichnet.
let peaxSchaerfereLadeLaeuft = false;
async function ladeSchaerferePeaxVorschau(eintrag) {
  if (peaxSchaerfereLadeLaeuft) return; // Doppelklick o.ae. ignorieren, sonst laufen zwei Ladevorgaenge parallel
  peaxSchaerfereLadeLaeuft = true;

  const btn = $('lbPeaxSchaerfer');
  const seitenBox = $('lbVorschauSeiten');
  const bild = $('lbVorschauBild');
  btn.disabled = true;
  btn.textContent = 'Lade … (kann einige Sekunden dauern)';

  let tab;
  try {
    tab = await new Promise((resolve, reject) => {
      chrome.tabs.create({ url: eintrag.link, active: false }, (t) => {
        if (chrome.runtime.lastError || !t) reject(new Error(chrome.runtime.lastError?.message || 'Tab konnte nicht geöffnet werden.'));
        else resolve(t);
      });
    });
    await new Promise((resolve) => {
      function listener(tabId, info) {
        if (tabId === tab.id && info.status === 'complete') {
          chrome.tabs.onUpdated.removeListener(listener);
          resolve();
        }
      }
      chrome.tabs.onUpdated.addListener(listener);
    });
    const antwort = await new Promise((resolve, reject) => {
      chrome.tabs.sendMessage(tab.id, { peaxAction: 'seiten-lesen' }, (res) => {
        if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
        else resolve(res);
      });
    });
    const seiten = antwort?.seiten || [];
    if (!seiten.length) {
      btn.textContent = 'Konnte keine Seiten lesen – bitte "Original öffnen" nutzen.';
      return;
    }
    seitenBox.innerHTML = seiten.map((src) => `<img src="${src}">`).join('');
    seitenBox.hidden = false;
    bild.hidden = true;
    btn.hidden = true;
  } catch (err) {
    btn.textContent = 'Fehler beim Laden – bitte "Original öffnen" nutzen.';
  } finally {
    btn.disabled = false;
    peaxSchaerfereLadeLaeuft = false;
    if (tab) chrome.tabs.remove(tab.id).catch(() => {});
  }
}
$('lbPeaxSchaerfer').addEventListener('click', () => {
  const e = lightboxListe[lightboxIndex];
  if (e) ladeSchaerferePeaxVorschau(e);
});
$('lbClose').addEventListener('click', closeLightbox);
$('lbPrev').addEventListener('click', () => navLightbox(-1));
$('lbNext').addEventListener('click', () => navLightbox(1));
$('lightbox').addEventListener('click', (ev) => { if (ev.target === $('lightbox')) closeLightbox(); });

// ---------------------------------------------------------------------------
// Vorschaubild per Maus verschieben (Bild ist groesser als der sichtbare
// Rahmen gerendert - Ziehen zeigt den Rest, ohne das Fenster selbst zu
// vergroessern).
// ---------------------------------------------------------------------------
(function () {
  const wrap = $('lbVorschauWrap');
  const bild = $('lbVorschauBild');
  let ziehtGerade = false;
  let startX = 0, startY = 0, curX = 0, curY = 0, minX = 0, minY = 0;

  bild.addEventListener('load', () => {
    curX = 0; curY = 0;
    bild.style.transform = 'translate(0px, 0px)';
    minX = Math.min(0, wrap.clientWidth - bild.offsetWidth);
    minY = Math.min(0, wrap.clientHeight - bild.offsetHeight);
  });

  wrap.addEventListener('mousedown', (ev) => {
    if (wrap.classList.contains('kein-ziehen')) return; // Drive-Einbettung scrollt selbst
    ziehtGerade = true;
    startX = ev.clientX - curX;
    startY = ev.clientY - curY;
    wrap.classList.add('greift');
  });
  window.addEventListener('mousemove', (ev) => {
    if (!ziehtGerade) return;
    curX = Math.min(0, Math.max(minX, ev.clientX - startX));
    curY = Math.min(0, Math.max(minY, ev.clientY - startY));
    bild.style.transform = `translate(${curX}px, ${curY}px)`;
  });
  window.addEventListener('mouseup', () => { ziehtGerade = false; wrap.classList.remove('greift'); });
})();

// PEAX-Suche: kein API-Zugang (offizielle Anbindung mit CHF 7'500.- offeriert,
// abgelehnt) - stattdessen wird PEAX' eigene Suchseite im Hintergrund
// geoeffnet, das Content-Script (peax-content.js) tippt den Suchbegriff in
// PEAX' eigenes Suchfeld und loest per Enter die Suche aus (bestaetigt: ein
// URL-Parameter funktioniert NICHT, PEAX' Suche laeuft rein clientseitig
// ohne Adressaenderung), danach wird die Ergebnisliste ausgelesen. Keine
// KI-Bewertung, PEAX' eigene Trefferliste wird 1:1 uebernommen.
async function suchePeax(query) {
  $('searchBtn').disabled = true;
  $('statusLine').textContent = 'Lese Ergebnisse direkt aus PEAX …';
  $('statusLine').className = 'status-line';
  $('resultsHeader').hidden = true;
  $('docList').innerHTML = '';
  $('suchschritteBox').hidden = true;

  let tab;
  try {
    tab = await new Promise((resolve, reject) => {
      chrome.tabs.create({ url: 'https://app.peax.ch/inbox/search', active: false }, (t) => {
        if (chrome.runtime.lastError || !t) reject(new Error(chrome.runtime.lastError?.message || 'Tab konnte nicht geöffnet werden.'));
        else resolve(t);
      });
    });
    await new Promise((resolve) => {
      function listener(tabId, info) {
        if (tabId === tab.id && info.status === 'complete') {
          chrome.tabs.onUpdated.removeListener(listener);
          resolve();
        }
      }
      chrome.tabs.onUpdated.addListener(listener);
    });
    const antwort = await new Promise((resolve, reject) => {
      chrome.tabs.sendMessage(tab.id, { peaxAction: 'suche', begriff: query }, (res) => {
        if (chrome.runtime.lastError) reject(new Error(chrome.runtime.lastError.message));
        else resolve(res);
      });
    });

    letzteErgebnisRohliste = antwort?.ergebnisse || [];
    $('sortSelect').value = 'relevanz';
    zeichneErgebnisse(letzteErgebnisRohliste);
    if (antwort && !antwort.sucheAusgeloest) {
      $('statusLine').textContent = 'PEAX-Suchfeld nicht gefunden (Seitenstruktur hat sich vermutlich geändert) - zeigt evtl. ungefilterte Ergebnisse. Bitte melden.';
      $('statusLine').className = 'status-line err';
    } else {
      $('statusLine').textContent = letzteErgebnisRohliste.length
        ? ''
        : 'Keine Treffer gefunden.';
    }
  } catch (e) {
    $('statusLine').textContent = 'Fehler bei der PEAX-Suche: ' + e.message;
    $('statusLine').className = 'status-line err';
  } finally {
    $('searchBtn').disabled = false;
    if (tab) chrome.tabs.remove(tab.id).catch(() => {});
  }
}

async function suchen() {
  const query = $('queryInput').value.trim();
  if (!query) return;

  if (aktiverTab === 'peax') {
    await suchePeax(query);
    return;
  }

  const token = await holeGespeichertenToken();
  if (!token) {
    $('connectBox').hidden = false;
    $('searchBox').hidden = true;
    $('connectStatus').textContent = 'Anmeldung ist abgelaufen, bitte erneut verbinden.';
    $('connectStatus').className = 'status-line err';
    return;
  }

  const quellen = aktiverTab === 'drive' ? ['drive'] : aktiverTab === 'gmail' ? ['gmail'] : ['drive', 'gmail'];
  const quellenText = quellen.length === 2 ? 'Drive/Gmail' : quellen[0] === 'drive' ? 'Drive' : 'Gmail';

  $('searchBtn').disabled = true;
  $('statusLine').textContent = $('anhaengeDurchsuchen').checked
    ? `KI durchsucht ${quellenText} inkl. Anhänge – kann spürbar länger dauern …`
    : `KI durchsucht ${quellenText}, kann ein paar Sekunden dauern …`;
  $('statusLine').className = 'status-line';
  $('resultsHeader').hidden = true;
  $('docList').innerHTML = '';
  $('suchschritteBox').hidden = true;

  try {
    const profil = await new Promise((resolve) => chrome.identity.getProfileUserInfo({ accountStatus: 'ANY' }, resolve));
    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      body: JSON.stringify({
        query,
        mitarbeiterEmail: profil?.email || 'unbekannt',
        googleAccessToken: token,
        quellen,
        zeitraumVon: $('zeitraumVon').value || undefined,
        zeitraumBis: $('zeitraumBis').value || undefined,
        kunde: $('kundeFeld').value.trim() || undefined,
        lieferant: $('lieferantFeld').value.trim() || undefined,
        dokumentarten: dokumentartAuswahl.getSelected(),
        dateiformate: dateiformatAuswahl.getSelected(),
        papierkorbSpam: $('papierkorbSpam').checked,
        anhaengeDurchsuchen: $('anhaengeDurchsuchen').checked,
        suchgenauigkeit: document.querySelector('.seg button[data-genauigkeit].active')?.dataset.genauigkeit || 'sinngemaess',
        maxRunden: Number(document.querySelector('.seg button[data-runden].active')?.dataset.runden || '7'),
        modell: document.querySelector('.seg button[data-modell].active')?.dataset.modell || 'sonnet',
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || `Fehler ${res.status}`);

    letzteErgebnisRohliste = data.ergebnisse || [];
    $('sortSelect').value = 'relevanz';
    zeichneErgebnisse(letzteErgebnisRohliste);

    const schritte = data.suchschritte || [];
    if (schritte.length) {
      $('suchschritteBox').hidden = false;
      $('suchschritteListe').innerHTML = schritte
        .map((s) => `<li>${s.quelle === 'drive' ? 'Drive' : 'Gmail'}: „${esc(s.begriff)}“</li>`)
        .join('');
    }

    if (data.fehler?.length) {
      $('statusLine').textContent = 'Teilweise fehlgeschlagen: ' + data.fehler.join(' / ');
      $('statusLine').className = 'status-line err';
    } else {
      $('statusLine').textContent = '';
    }
  } catch (e) {
    $('statusLine').textContent = 'Fehler: ' + e.message;
    $('statusLine').className = 'status-line err';
  } finally {
    $('searchBtn').disabled = false;
  }
}

$('connectBtn').addEventListener('click', verbinden);
$('searchBtn').addEventListener('click', suchen);
$('queryInput').addEventListener('keydown', (e) => { if (e.key === 'Enter') suchen(); });

// ---------------------------------------------------------------------------
// Start: pruefen, ob schon ein gueltiges Google-Token vorliegt.
// ---------------------------------------------------------------------------
(async () => {
  const token = await holeGespeichertenToken();
  if (token) zeigeSuche();
})();
