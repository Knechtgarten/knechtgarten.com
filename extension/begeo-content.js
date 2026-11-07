// ============================================================================
// be-geo (Shop der Berner Geometer): Bestellung «Situationsplan zu Baugesuch
// beglaubigt» vorausfüllen.
//
// «Pläne & Bewill.» öffnet be-geo mit #kg=<JSON {s: Suchbegriff, g: Gemeinde,
// p: Parzelle}>. Das Skript merkt sich den Auftrag (auch über Anmeldung und
// Weiterleitung hinweg, 1 Stunde gültig) und füllt im Bestellformular das Feld
// «Suche nach Gemeinde, Adresse, Parzelle…» aus (gds-form-geosearch), wählt
// den Treffer mit der richtigen Parzelle (gds-option) und kreuzt
// «Eigentümerliste» an. Planart (Papier/CAD) und «weiter» klickt man selbst.
// ============================================================================
(function () {
  const KEY = 'kg_begeo_auftrag', GUELTIG = 60 * 60 * 1000;

  // 1. Auftrag aus der Adresse übernehmen (läuft vor Angular, also auch vor einer Weiterleitung zur Anmeldung)
  const m = location.hash.match(/[#&]kg=([^&]+)/);
  if (m) {
    try {
      const a = JSON.parse(decodeURIComponent(m[1]));
      if (a && a.s) chrome.storage.local.set({ [KEY]: { ...a, zeit: Date.now() } });
    } catch (_) { /* kaputter Auftrag: ignorieren */ }
    history.replaceState(null, '', location.pathname + location.search);
  }

  function hinweis(text, fehler) {
    const el = document.createElement('div');
    el.textContent = text;
    el.style.cssText = `position:fixed;right:16px;bottom:16px;z-index:2147483647;max-width:340px;padding:10px 14px;border-radius:10px;
      font:13px/1.4 -apple-system,Segoe UI,Arial,sans-serif;color:#fff;background:${fehler ? '#7A2638' : '#323E4E'};box-shadow:0 6px 20px rgba(0,0,0,.25)`;
    document.body.appendChild(el); setTimeout(() => el.remove(), 7000);
  }
  const warte = ms => new Promise(ok => setTimeout(ok, ms));
  const sichtbar = el => !!(el && el.offsetParent !== null);

  // Wert so setzen, dass Angular (formControl) es mitbekommt
  function tippen(input, wert) {
    input.focus();
    const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
    setter.call(input, wert);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: wert.slice(-1) }));
  }
  function klicken(el) {
    ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(t => el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window })));
  }

  let laeuft = false, zuletzt = 0;
  async function ausfuellen() {
    if (laeuft || Date.now() - zuletzt < 1500) return;   // nicht bei jeder kleinen Änderung im Speicher nachschauen
    zuletzt = Date.now();
    const feld = document.querySelector('gds-form-geosearch input');
    if (!sichtbar(feld)) return;
    const { [KEY]: a } = await chrome.storage.local.get(KEY);
    if (!a || Date.now() - a.zeit > GUELTIG) return;
    laeuft = true;
    try {
      await chrome.storage.local.remove(KEY);   // nur einmal ausfüllen
      tippen(feld, a.s);
      // Treffer abwarten und den mit der Parzellennummer (und möglichst der Gemeinde) wählen
      const p = String(a.p || '').trim(), g = String(a.g || '').toLowerCase();
      const passt = t => p && new RegExp(`(^|\\D)${p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(\\D|$)`).test(t);
      let treffer = null;
      for (let i = 0; i < 40 && !treffer; i++) {
        await warte(250);
        const opt = [...document.querySelectorAll('gds-option')].filter(sichtbar);
        treffer = opt.find(o => passt(o.textContent) && (!g || o.textContent.toLowerCase().includes(g))) || opt.find(o => passt(o.textContent));
      }
      if (!treffer) { hinweis(`Knechtgarten: «${a.s}» eingegeben – bitte den passenden Treffer wählen.`); return; }
      klicken(treffer);
      await warte(600);
      // Eigentümerliste ankreuzen (falls nicht schon an)
      const lab = [...document.querySelectorAll('label, gds-checkbox, .gds-checkbox')].find(x => /Eigentümerliste/i.test(x.textContent));
      const cb = lab && (lab.querySelector('input[type=checkbox]') || (lab.htmlFor && document.getElementById(lab.htmlFor)));
      if (cb && !cb.checked) klicken(cb);
      hinweis(`Knechtgarten: Parzelle ${p}${a.g ? ', ' + a.g : ''} eingesetzt. Planart wählen und «weiter».`);
    } catch (e) {
      hinweis('Knechtgarten: Ausfüllen hat nicht geklappt – ' + (e?.message || e), true);
    } finally { laeuft = false; }
  }

  // 2. Angular baut die Seiten nach und nach auf: auf das Bestellformular warten
  const beobachter = new MutationObserver(() => ausfuellen());
  const start = () => { beobachter.observe(document.documentElement, { childList: true, subtree: true }); ausfuellen(); };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
  setInterval(ausfuellen, 2000);   // falls das Formular ohne weitere Änderungen erscheint
})();
