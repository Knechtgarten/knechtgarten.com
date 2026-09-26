// ============================================================================
// Dokumenten-Suche - Seitenpanel-Logik.
//
// Ablauf: Google-Login per chrome.identity.launchWebAuthFlow (implizites
// Token, kein Client-Secret im Code - siehe extension/erweiterungs-id.md fuer
// die feste Erweiterungs-ID/Redirect-URI). Token wird in chrome.storage.local
// zwischengespeichert und bis zum Ablauf wiederverwendet. Die eigentliche
// Suche laeuft ueber die Supabase Edge Function "dokumenten-suche" (Phase 3:
// Claude orchestriert die Google-Suche selbst und bewertet die Treffer).
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
// Google-Login
// ---------------------------------------------------------------------------
function baueAuthUrl() {
  const redirectUri = chrome.identity.getRedirectURL();
  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    response_type: 'token',
    redirect_uri: redirectUri,
    scope: GOOGLE_SCOPES.join(' '),
  });
  return `https://accounts.google.com/o/oauth2/v2/auth?${params}`;
}

function parseTokenAusRedirect(redirectUrl) {
  const fragment = new URL(redirectUrl).hash.slice(1);
  const params = new URLSearchParams(fragment);
  const accessToken = params.get('access_token');
  const expiresIn = Number(params.get('expires_in') || '3600');
  if (!accessToken) throw new Error('Kein access_token in der Antwort von Google.');
  return { accessToken, ablaufZeit: Date.now() + expiresIn * 1000 };
}

async function holeGespeichertenToken() {
  const { googleToken } = await chrome.storage.local.get('googleToken');
  if (!googleToken) return null;
  // 60 Sekunden Puffer vor dem eigentlichen Ablauf.
  if (googleToken.ablaufZeit < Date.now() + 60_000) return null;
  return googleToken.accessToken;
}

function verbinden() {
  $('connectStatus').textContent = 'Google-Anmeldefenster öffnet sich …';
  $('connectStatus').className = 'status-line';
  chrome.identity.launchWebAuthFlow({ url: baueAuthUrl(), interactive: true }, async (redirectUrl) => {
    if (chrome.runtime.lastError || !redirectUrl) {
      $('connectStatus').textContent = 'Anmeldung fehlgeschlagen: ' + (chrome.runtime.lastError?.message || 'abgebrochen');
      $('connectStatus').className = 'status-line err';
      return;
    }
    try {
      const token = parseTokenAusRedirect(redirectUrl);
      await chrome.storage.local.set({ googleToken: token });
      zeigeSuche();
    } catch (e) {
      $('connectStatus').textContent = 'Fehler: ' + e.message;
      $('connectStatus').className = 'status-line err';
    }
  });
}

function zeigeSuche() {
  $('connectBox').hidden = true;
  $('searchBox').hidden = false;
}

// ---------------------------------------------------------------------------
// Quelle-Chips (Drive/Gmail toggle, PEAX separat)
// ---------------------------------------------------------------------------
document.querySelectorAll('.chip[data-quelle]').forEach((chip) => {
  chip.addEventListener('click', () => chip.classList.toggle('active'));
});

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

$('peaxBtn').addEventListener('click', () => {
  // TODO: Sobald bestaetigt ist, welcher URL-Parameter PEAX' Suchseite fuer
  // einen vorausgefuellten Suchbegriff akzeptiert, hier ergaenzen
  // (z.B. ?q=... oder ?search=...). Bis dahin oeffnet der Button nur die
  // Suchseite selbst, der Begriff muesste manuell eingetippt werden.
  chrome.tabs.create({ url: 'https://app.peax.ch/inbox/search' });
});

// ---------------------------------------------------------------------------
// Suche
// ---------------------------------------------------------------------------
// An Original-Icons angelehnt (bewusste Ausnahme vom sonst einheitlichen
// Linien-Icon-Stil - Dateityp-Erkennung lebt von den bekannten Farbcodes),
// gleiche SVGs wie im Mockup "Suchpanel".
const FTYPE_ICONS = {
  pdf: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#F7B4AC"/><rect x="5" y="14" width="14" height="6" rx="1" fill="#DB4437"/><text x="12" y="18.6" font-size="5" font-weight="700" fill="#fff" text-anchor="middle" font-family="Arial, sans-serif">PDF</text></svg>',
  docs: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#A4C2F4"/><rect x="7.5" y="10" width="9" height="1.4" rx=".5" fill="#4285F4"/><rect x="7.5" y="13" width="9" height="1.4" rx=".5" fill="#4285F4"/><rect x="7.5" y="16" width="6" height="1.4" rx=".5" fill="#4285F4"/></svg>',
  sheets: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#A8DAB5"/><rect x="7.5" y="10" width="9" height="7" fill="none" stroke="#0F9D58" stroke-width="1"/><line x1="7.5" y1="13.5" x2="16.5" y2="13.5" stroke="#0F9D58" stroke-width="1"/><line x1="11.8" y1="10" x2="11.8" y2="17" stroke="#0F9D58" stroke-width="1"/></svg>',
  mail: '<svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2" fill="#EA4335"/><path d="M3 6l9 6.5L21 6" fill="none" stroke="#fff" stroke-width="1.4"/></svg>',
  generic: '<svg viewBox="0 0 24 24"><path d="M6 2h9l5 5v15a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1z" fill="#fff" stroke="#DADCE0"/><path d="M15 2v5h5z" fill="#D7D3CE"/></svg>',
};
function ftypeIcon(dateityp, quelle) {
  if (quelle === 'gmail') return FTYPE_ICONS.mail;
  if (dateityp === 'application/pdf') return FTYPE_ICONS.pdf;
  if (dateityp === 'application/vnd.google-apps.document') return FTYPE_ICONS.docs;
  if (dateityp === 'application/vnd.google-apps.spreadsheet') return FTYPE_ICONS.sheets;
  return FTYPE_ICONS.generic;
}

function fmtDatum(iso) {
  if (!iso) return '';
  return new Date(iso).toLocaleDateString('de-CH');
}

let letzteErgebnisse = [];
let aktiverDokumentartFilter = null; // null = "Alle"

function renderDokumentartFilter() {
  const arten = [...new Set(letzteErgebnisse.map((e) => e.dokumentart).filter(Boolean))];
  const row = $('dokumentartFilterRow');
  if (!arten.length) { row.hidden = true; row.innerHTML = ''; return; }

  row.hidden = false;
  row.innerHTML = '';
  const alleChip = document.createElement('span');
  alleChip.className = 'chip' + (aktiverDokumentartFilter === null ? ' active' : '');
  alleChip.textContent = 'Alle';
  alleChip.addEventListener('click', () => { aktiverDokumentartFilter = null; renderDokumentartFilter(); zeichneGefilterteErgebnisse(); });
  row.appendChild(alleChip);

  for (const art of arten) {
    const chip = document.createElement('span');
    chip.className = 'chip' + (aktiverDokumentartFilter === art ? ' active' : '');
    chip.textContent = art;
    chip.addEventListener('click', () => { aktiverDokumentartFilter = art; renderDokumentartFilter(); zeichneGefilterteErgebnisse(); });
    row.appendChild(chip);
  }
}

function zeichneGefilterteErgebnisse() {
  const gefiltert = aktiverDokumentartFilter === null
    ? letzteErgebnisse
    : letzteErgebnisse.filter((e) => e.dokumentart === aktiverDokumentartFilter);
  zeichneErgebnisse(gefiltert);
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
      </span>`;
    row.querySelector('.doc-title').textContent = e.titel;
    const badge = row.querySelector('.match-badge');
    badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hoch' : 'Möglich';
    badge.classList.add(e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
    row.querySelector('.doc-meta').textContent = `${e.quelle === 'drive' ? 'Drive' : 'Gmail'} · ${fmtDatum(e.datum)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
    row.querySelector('.doc-begruendung').textContent = e.begruendung || '';
    row.addEventListener('click', () => openLightbox(i));
    $('docList').appendChild(row);
  });
}

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
  $('lbMeta').textContent = `${e.quelle === 'drive' ? 'Drive' : 'Gmail'} · ${fmtDatum(e.datum)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
  const badge = $('lbMatch');
  badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hohe Übereinstimmung' : 'Mögliche Übereinstimmung';
  badge.className = 'match-badge ' + (e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
  $('lbBody').textContent = e.begruendung || '';
  $('lbPosition').textContent = `${lightboxIndex + 1} von ${lightboxListe.length}`;
  $('lbOpen').onclick = () => chrome.tabs.create({ url: e.link });
}
$('lbClose').addEventListener('click', closeLightbox);
$('lbPrev').addEventListener('click', () => navLightbox(-1));
$('lbNext').addEventListener('click', () => navLightbox(1));
$('lightbox').addEventListener('click', (ev) => { if (ev.target === $('lightbox')) closeLightbox(); });

async function suchen() {
  const query = $('queryInput').value.trim();
  if (!query) return;

  const token = await holeGespeichertenToken();
  if (!token) {
    $('connectBox').hidden = false;
    $('searchBox').hidden = true;
    $('connectStatus').textContent = 'Anmeldung ist abgelaufen, bitte erneut verbinden.';
    $('connectStatus').className = 'status-line err';
    return;
  }

  const quellen = Array.from(document.querySelectorAll('.chip[data-quelle].active'))
    .map((c) => c.dataset.quelle);

  $('searchBtn').disabled = true;
  $('statusLine').textContent = 'KI durchsucht Drive/Gmail, kann ein paar Sekunden dauern …';
  $('statusLine').className = 'status-line';
  $('resultsHeader').hidden = true;
  $('docList').innerHTML = '';
  $('dokumentartFilterRow').hidden = true;

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
        papierkorbSpam: $('papierkorbSpam').checked,
        suchgenauigkeit: document.querySelector('.seg button[data-genauigkeit].active')?.dataset.genauigkeit || 'sinngemaess',
        maxRunden: Number(document.querySelector('.seg button[data-runden].active')?.dataset.runden || '4'),
      }),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || `Fehler ${res.status}`);

    letzteErgebnisse = data.ergebnisse || [];
    aktiverDokumentartFilter = null;
    renderDokumentartFilter();
    zeichneGefilterteErgebnisse();
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
