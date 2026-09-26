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
  ladeDokumentarten();
}

// ---------------------------------------------------------------------------
// Quelle-Chips (Drive/Gmail toggle, PEAX separat)
// ---------------------------------------------------------------------------
const quelleChips = document.querySelectorAll('.chip[data-quelle]');
function aktualisiereQuelleAlle() {
  $('quelleAlleBtn').classList.toggle('active', Array.from(quelleChips).every((c) => c.classList.contains('active')));
}
quelleChips.forEach((chip) => {
  chip.addEventListener('click', () => { chip.classList.toggle('active'); aktualisiereQuelleAlle(); });
});
$('quelleAlleBtn').addEventListener('click', () => {
  quelleChips.forEach((c) => c.classList.add('active'));
  aktualisiereQuelleAlle();
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
};
function ftypeIcon(dateityp, quelle) {
  if (quelle === 'gmail') return FTYPE_ICONS.mail;
  if (dateityp === 'application/pdf') return FTYPE_ICONS.pdf;
  if (dateityp === 'application/vnd.google-apps.document') return FTYPE_ICONS.docs;
  if (dateityp === 'application/vnd.google-apps.spreadsheet') return FTYPE_ICONS.sheets;
  if (dateityp?.startsWith('image/')) return FTYPE_ICONS.bild;
  return FTYPE_ICONS.generic;
}

const SOURCE_ICONS = {
  drive: '<svg viewBox="0 0 24 24"><path fill="#4285F4" d="M8.5 3h7l7.5 13-3.5 6h-15z"/><path fill="#34A853" d="M4.5 22l3.5-6h15l-3.5 6z"/><path fill="#FBBC05" d="M8.5 3l-4 7 4 6.5 4-6.5z"/></svg>',
  gmail: '<svg viewBox="0 0 24 24"><rect x="2" y="4" width="20" height="16" rx="2" fill="#EA4335"/><path fill="#fff" d="M4 6l8 6 8-6v2l-8 6-8-6z"/></svg>',
};

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
  } catch (e) {
    console.error('Dokumentarten laden fehlgeschlagen:', e);
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
    badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hoch' : 'Möglich';
    badge.classList.add(e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
    row.querySelector('.doc-meta').innerHTML = `<span class="src-icon">${SOURCE_ICONS[e.quelle] || ''}</span>${e.quelle === 'drive' ? 'Drive' : 'Gmail'} · ${fmtDatum(e.datum)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
    row.querySelector('.doc-begruendung').textContent = e.begruendung || '';
    row.addEventListener('click', () => openLightbox(i));
    $('docList').appendChild(row);
  });
}

// ---------------------------------------------------------------------------
// Sortierung (Relevanz = Original-Reihenfolge der KI, sonst Datum/Dateityp).
// ---------------------------------------------------------------------------
let letzteErgebnisRohliste = [];
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
  $('lbMeta').innerHTML = `<span class="src-icon">${SOURCE_ICONS[e.quelle] || ''}</span>${e.quelle === 'drive' ? 'Drive' : 'Gmail'} · ${fmtDatum(e.datum)}${e.dokumentart ? ' · ' + e.dokumentart : ''}`;
  const badge = $('lbMatch');
  badge.textContent = e.uebereinstimmung === 'hoch' ? 'Hohe Übereinstimmung' : 'Mögliche Übereinstimmung';
  badge.className = 'match-badge ' + (e.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich');
  $('lbBody').textContent = e.begruendung || '';
  $('lbPosition').textContent = `${lightboxIndex + 1} von ${lightboxListe.length}`;
  // Öffnet im Hintergrund (active:false), damit der Tab, in dem gerade
  // weitergearbeitet wird (z.B. Easybill), nicht weggeschnappt wird.
  $('lbOpen').onclick = () => chrome.tabs.create({ url: e.link, active: false });

  const wrap = $('lbVorschauWrap');
  const bild = $('lbVorschauBild');
  if (e.vorschauBild) {
    wrap.hidden = false;
    bild.src = e.vorschauBild;
    bild.onerror = () => { wrap.hidden = true; };
  } else {
    wrap.hidden = true;
    bild.removeAttribute('src');
  }
}
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
