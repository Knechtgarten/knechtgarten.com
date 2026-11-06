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
  const auftrag = (evv) => new Promise((ok) => { const n = ++nr; warten.set(n, ok); window.postMessage({ kanal: KANAL, typ: 'auftrag', nr: n, evv }, '*');
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
})();
