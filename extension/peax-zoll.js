// ============================================================================
// Zoll in PEAX – Steuerung (Content-Script, isoliert).
//
// Beim Öffnen von PEAX (nach kurzer Wartezeit) und danach alle 15 Minuten:
// offene MWST-Verfügungen bei der Edge Function «zoll» holen (Google-Konto
// @knechtgarten.ch als Ausweis, mit Riegel gegen Doppelarbeit), jede einzeln
// von peax-zoll-main.js anhängen lassen und das Resultat zurückmelden.
// Eindeutige Treffer werden ohne Klick angehängt; unten rechts erscheint ein
// kurzer Hinweis. Nicht gefundene Rechnungen werden später erneut versucht.
// ============================================================================
(function () {
  const FN = 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/zoll';
  const ANON = 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P';
  const KANAL = 'kg-zoll';
  let nr = 0, laeuft = false;
  const warten = new Map();

  window.addEventListener('message', (e) => {
    if (e.source !== window || e.data?.kanal !== KANAL || e.data.typ !== 'antwort') return;
    const w = warten.get(e.data.nr); if (w) { warten.delete(e.data.nr); w(e.data.antwort); }
  });
  const auftrag = (evv, typ = 'auftrag') => new Promise((ok) => { const n = ++nr; warten.set(n, ok); window.postMessage({ kanal: KANAL, typ, nr: n, evv }, '*');
    setTimeout(() => { if (warten.has(n)) { warten.delete(n); ok({ ergebnis: 'fehler', hinweis: 'Zeitüberschreitung' }); } }, 120000); });

  const fn = async (body) => { const r = await fetch(FN, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${ANON}` }, body: JSON.stringify(body) });
    const d = await r.json().catch(() => ({})); if (!r.ok) throw new Error(d.error || 'Fehler ' + r.status); return d; };

  function hinweis(text, fehler) {
    const el = document.createElement('div');
    el.textContent = text;
    el.style.cssText = `position:fixed;right:20px;bottom:20px;z-index:2147483647;max-width:380px;padding:10px 14px;border-radius:10px;font:13px/1.4 -apple-system,Segoe UI,Arial,sans-serif;color:#fff;background:${fehler ? '#B4655F' : '#323E4E'};box-shadow:0 6px 20px rgba(0,0,0,.2);`;
    document.body.appendChild(el); setTimeout(() => el.remove(), 9000);
  }

  async function lauf() {
    if (laeuft) return; laeuft = true;
    try {
      const token = await new Promise((ok) => chrome.runtime.sendMessage({ kg: 'googleToken' }, (r) => ok(r?.token || null)));
      if (!token) return;   // nicht mit Google verbunden: still nichts tun
      const { evv = [] } = await fn({ aktion: 'offen', googleAccessToken: token });
      const fertig = [];
      for (const v of evv) {
        const a = await auftrag(v);
        if (a.ergebnis === 'fehler') { await fn({ aktion: 'ergebnis', googleAccessToken: token, id: v.id, ergebnis: 'nicht_gefunden', hinweis: 'Fehler: ' + a.hinweis }).catch(() => {}); continue; }
        await fn({ aktion: 'ergebnis', googleAccessToken: token, id: v.id, ...a }).catch(() => {});
        if (a.ergebnis === 'angehaengt') fertig.push(a.peax_titel || v.zanr);
      }
      if (fertig.length) hinweis(`${fertig.length} Zolldokument${fertig.length > 1 ? 'e' : ''} angehängt: ${fertig.join(', ')}`);
    } catch (e) {
      console.warn('Knechtgarten Zoll:', e);
    } finally { laeuft = false; }
  }

  setTimeout(lauf, 8000);
  setInterval(lauf, 15 * 60000);

  // --------------------------------------------------------------------------
  // Knopf «Verfügung anfordern» (e-dec, bis Herbst 2027): beim Öffnen einer
  // Spediteur-Rechnung Nummer + Zugangscode per KI lesen (Ergebnis pro Dokument
  // gemerkt), unten rechts Stand pro Zollanmeldung zeigen. Der Knopf öffnet
  // e-dec-web, edec-content.js füllt Nummer, Code und zoll@knechtgarten.ch aus.
  // --------------------------------------------------------------------------
  const EDEC = 'https://e-dec-web.ezv.admin.ch/edecZugangscodeGui/';
  const SPEDITEUR = /dpd|dsv|dhl|post|ups|fedex|tnt|gls|transfreight|schneider|fiege|wedeclare|pflanzen-transport|streck|planzer|schenker|kuehne|kühne|gondrand|emons|imlig|zoll|cargo|logisti|transport|spedition|freight|express/i;
  let offenesDok = null;

  const speicher = {
    holen: (k) => new Promise((ok) => chrome.storage.local.get(k, (r) => ok(r[k]))),
    setzen: (k, v) => new Promise((ok) => chrome.storage.local.set({ [k]: v }, ok)),
  };

  function panelWeg() { document.getElementById('kg-zoll-panel')?.remove(); }
  function panel(liste) {
    panelWeg();
    const p = document.createElement('div');
    p.id = 'kg-zoll-panel';
    p.style.cssText = 'position:fixed;right:20px;bottom:20px;z-index:2147483646;width:330px;background:#fff;border:1px solid #DCE1E7;border-radius:10px;box-shadow:0 6px 20px rgba(0,0,0,.15);font:13px/1.4 -apple-system,Segoe UI,Arial,sans-serif;color:#323E4E;padding:10px 12px;';
    const kopf = document.createElement('div');
    kopf.style.cssText = 'display:flex;justify-content:space-between;align-items:center;font-weight:700;margin-bottom:6px;';
    kopf.textContent = 'Zoll · MWST-Verfügung';
    const zu = document.createElement('button');
    zu.textContent = '×'; zu.title = 'Schliessen';
    zu.style.cssText = 'all:unset;cursor:pointer;color:#8B9097;font-size:16px;padding:0 4px;';
    zu.onclick = panelWeg; kopf.appendChild(zu); p.appendChild(kopf);
    for (const z of liste) {
      const zeile = document.createElement('div');
      zeile.style.cssText = 'display:flex;justify-content:space-between;align-items:center;gap:8px;padding:5px 0;border-top:1px solid #EEF1F4;';
      const nrEl = document.createElement('span'); nrEl.textContent = z.nr; nrEl.style.cssText = 'font-family:Consolas,monospace;font-size:12px;';
      zeile.appendChild(nrEl);
      const rechts = document.createElement('span'); rechts.style.cssText = 'font-size:12px;color:#8B9097;white-space:nowrap;';
      if (z.stand === 'angehaengt') rechts.textContent = 'angehängt';
      else if (z.stand === 'vorhanden') rechts.textContent = 'eingegangen, wird angehängt';
      else if (!z.edec) rechts.textContent = 'kommt über Passar';
      else if (!z.code) rechts.textContent = 'kein Zugangscode gefunden';
      else {
        const b = document.createElement('button');
        b.textContent = 'Verfügung anfordern';
        b.style.cssText = 'all:unset;cursor:pointer;background:#323E4E;color:#fff;font-weight:700;font-size:12px;border-radius:7px;padding:5px 10px;';
        b.onclick = async () => { await speicher.setzen('edecAuftrag', { zanr: z.nr, code: z.code, zeit: Date.now() }); window.open(EDEC, '_blank'); };
        rechts.appendChild(b);
      }
      zeile.appendChild(rechts); p.appendChild(zeile);
    }
    document.body.appendChild(p);
  }

  async function dokumentPruefen(id) {
    let info = await speicher.holen('zollDok:' + id);
    if (!info) {
      const d = await auftrag({ id }, 'pdf');
      if (d.fehler || d.skip) { if (d.skip) await speicher.setzen('zollDok:' + id, { liste: [] }); return; }
      if (!SPEDITEUR.test(d.sender + ' ' + d.titel)) { await speicher.setzen('zollDok:' + id, { liste: [] }); return; }
      const token = await new Promise((ok) => chrome.runtime.sendMessage({ kg: 'googleToken' }, (r) => ok(r?.token || null)));
      if (!token) return;
      const r = await fn({ aktion: 'lesen', googleAccessToken: token, pdf: d.pdf });
      info = { liste: (r.zollanmeldungen || []).map(({ nr, code, edec }) => ({ nr, code, edec })) };
      await speicher.setzen('zollDok:' + id, info);
    }
    if (offenesDok !== id || !info.liste.length) return;
    // Stand (angehängt / eingegangen) jedes Mal frisch, Nummer und Code aus dem Speicher
    if (info.liste.some((z) => z.edec)) {
      const token = await new Promise((ok) => chrome.runtime.sendMessage({ kg: 'googleToken' }, (r) => ok(r?.token || null)));
      const stand = token ? await fn({ aktion: 'stand', googleAccessToken: token, nrn: info.liste.map((z) => z.nr) }).catch(() => null) : null;
      info.liste.forEach((z) => { z.stand = stand?.stand?.[z.nr] || null; });
    }
    if (offenesDok === id) panel(info.liste);
  }

  let letzterPfad = '';
  setInterval(() => {
    if (location.pathname === letzterPfad) return;
    letzterPfad = location.pathname;
    const m = location.pathname.match(/^\/inbox\/[^/]+\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/);
    offenesDok = m ? m[1] : null;
    panelWeg();
    if (offenesDok) dokumentPruefen(offenesDok).catch((e) => console.warn('Knechtgarten Zoll:', e));
  }, 1000);
})();
