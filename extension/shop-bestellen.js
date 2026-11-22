// ============================================================================
// QR-Bestellung: Artikel in den Warenkorb eines Lieferanten-Shops legen (läuft in background.js).
// Pro Shop-System ein Ablauf (heute: Magento, z. B. Aquasolar). Was sich ändern kann (Shop-Adresse, Sprache,
// Adresse der Bestätigungsseite), kommt vom Tool aus der Tabelle bestell_anbindung mit – kein Code im Tool.
//
// Ablauf «bestellen»: Shop-Warenkorb im eigenen Browser öffnen (du bist dort angemeldet), Artikelnummern im Shop
// suchen, Mengen über die normale Warenkorb-Funktion hineinlegen, unsere Notiz ins Kommentarfeld der Position,
// danach prüfen, was wirklich im Warenkorb liegt. Abschicken macht immer der Mensch im Shop.
// Bestätigung: Öffnet der Tab danach die Bestätigungsseite (Adresse enthält anbindung.bestaetigung), merkt sich die
// Erweiterung das; die Seite QR-Bestellung holt es ab und setzt die Positionen auf «Bestellt».
// ============================================================================

const SHOP_OFFEN = 'kgShopOffen', SHOP_BESTAETIGT = 'kgShopBestaetigt';
const ladeListe = async (k) => (await chrome.storage.local.get(k))[k] || [];
const speichereListe = (k, v) => chrome.storage.local.set({ [k]: v });

function warteAufTab(id, sek = 40) {
  return new Promise((ok) => {
    let fertig = false;
    const ende = (v) => { if (fertig) return; fertig = true; chrome.tabs.onUpdated.removeListener(hoer); clearTimeout(t); ok(v); };
    const hoer = (tid, info) => { if (tid === id && info.status === 'complete') ende(true); };
    const t = setTimeout(() => ende(false), sek * 1000);
    chrome.tabs.onUpdated.addListener(hoer);
    chrome.tabs.get(id).then((tab) => { if (tab.status === 'complete') ende(true); }).catch(() => ende(false));
  });
}

async function shopTab(a, aktiv) {
  const basis = a.shop_url.replace(/\/+$/, ''), url = `${basis}/${a.sprache || 'de'}/checkout/cart/`;
  const offen = await chrome.tabs.query({ url: basis + '/*' });
  let tab = offen[0], eigen = false;
  if (tab) await chrome.tabs.update(tab.id, { url, active: aktiv });
  else { tab = await chrome.tabs.create({ url, active: aktiv }); eigen = true; }
  await pause(300);
  await warteAufTab(tab.id);
  return { id: tab.id, eigen };
}

// ---------- Magento (läuft im Shop-Tab, Welt MAIN, darum ganz eigenständig) ----------
async function magentoAblauf(auftrag, pos, sprache) {
  const fk = (window.hyva && window.hyva.getFormKey && window.hyva.getFormKey()) || (document.cookie.match(/(?:^|;\s*)form_key=([^;]+)/) || [])[1];
  const acc = await fetch(`/${sprache}/customer/account/`, { credentials: 'include' });
  if (/\/login/.test(acc.url)) return { fehler: 'Im Shop nicht angemeldet. Bitte im Shop anmelden und nochmals starten.' };
  if (!fk) return { fehler: 'Shop-Seite nicht bereit (Formular-Schlüssel fehlt).' };
  const nrn = [...new Set(pos.map((p) => String(p.nr)))];
  const g = await fetch('/graphql?query=' + encodeURIComponent(`{products(filter:{sku:{in:${JSON.stringify(nrn)}}}){items{id sku}}}`))
    .then((r) => r.json()).catch(() => null);
  if (!g || !g.data) return { fehler: 'Produktsuche des Shops antwortet nicht.' };
  const ids = new Map((g.data.products.items || []).map((i) => [String(i.sku), i.id]));
  if (auftrag === 'test') return { eingeloggt: true, gefunden: nrn.filter((n) => ids.has(n)), fehlt: nrn.filter((n) => !ids.has(n)) };

  const post = (url, o) => fetch(url, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-Requested-With': 'XMLHttpRequest' },
    body: new URLSearchParams({ ...o, form_key: fk }) });
  // Warenkorb lesen: Positionen aus der Warenkorb-Seite (id, Menge, Kommentar, Artikelnummer)
  const warenkorb = async () => {
    const html = await fetch(`/${sprache}/checkout/cart/`, { credentials: 'include' }).then((r) => r.text());
    const d = new DOMParser().parseFromString(html, 'text/html');
    return [...d.querySelectorAll('input[name^="cart["][name$="[qty]"]')].map((inp) => {
      const id = inp.name.match(/cart\[(\d+)\]/)[1];
      let zeile = inp; while (zeile.parentElement && zeile.parentElement.querySelectorAll('input[name$="[qty]"]').length === 1) zeile = zeile.parentElement;
      const text = zeile.textContent || '';
      const nr = nrn.find((n) => new RegExp('(^|[^0-9A-Za-z])' + n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '([^0-9A-Za-z]|$)').test(text)) || null;
      const k = d.querySelector(`[name="cart[${id}][item_comment]"]`);
      return { id, nr, menge: parseFloat(inp.value) || 0, kommentar: k ? k.value : null };
    });
  };
  const summe = (wk, nr) => wk.filter((w) => w.nr === nr).reduce((s, w) => s + w.menge, 0);

  const vorher = await warenkorb(), fehler = [], gesendet = [];
  for (const p of pos) {
    const id = ids.get(String(p.nr));
    if (!id) { fehler.push({ nr: p.nr, grund: 'im Shop nicht gefunden' }); continue; }
    const r = await post(`/${sprache}/checkout/cart/add/`, { product: String(id), qty: String(p.menge) }).catch(() => null);
    if (!r || !r.ok) { fehler.push({ nr: p.nr, grund: 'Shop-Fehler ' + (r ? r.status : '') }); continue; }
    gesendet.push(p);
  }
  const nachher = await warenkorb(), ok = [];
  for (const p of gesendet) {
    if (summe(nachher, String(p.nr)) > summe(vorher, String(p.nr))) ok.push(p.nr);
    else fehler.push({ nr: p.nr, grund: 'nicht im Warenkorb gelandet' });
  }
  // Notiz ins Kommentarfeld, nur wo noch keiner steht
  const upd = {};
  for (const p of gesendet.filter((x) => x.notiz && ok.includes(x.nr))) {
    const w = nachher.find((x) => x.nr === String(p.nr) && x.kommentar === '');
    if (w) { upd[`cart[${w.id}][qty]`] = String(w.menge); upd[`cart[${w.id}][item_comment]`] = String(p.notiz).slice(0, 250); }
  }
  if (Object.keys(upd).length) await post(`/${sprache}/checkout/cart/updatePost/`, { update_cart_action: 'update_qty', ...upd }).catch(() => null);
  return { ok, fehler };
}
const ABLAEUFE = { magento: magentoAblauf };

async function shopAuftrag(typ, daten) {
  if (typ === 'bestaetigungen') return { liste: await ladeListe(SHOP_BESTAETIGT) };
  if (typ === 'quittieren') {
    const weg = new Set(daten?.laeufe || []);
    await speichereListe(SHOP_BESTAETIGT, (await ladeListe(SHOP_BESTAETIGT)).filter((b) => !weg.has(b.lauf)));
    return { ok: true };
  }
  const a = daten?.anbindung, ablauf = a && ABLAEUFE[a.plattform];
  if (!ablauf || !/^https:\/\//.test(a.shop_url || '')) return { fehler: 'Shop-System wird von dieser Version der Erweiterung nicht unterstützt.' };
  let tab;
  try { tab = await shopTab(a, typ === 'bestellen'); }
  catch (e) { return { fehler: 'Shop konnte nicht geöffnet werden: ' + (e?.message || e) + '. Ist die Erweiterung für diesen Shop freigegeben?' }; }
  let erg;
  try {
    const [r] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, world: 'MAIN', func: ablauf,
      args: [typ === 'test' ? 'test' : 'bestellen', daten.positionen || [], a.sprache || 'de'] });
    erg = r?.result || { fehler: 'Keine Antwort vom Shop.' };
  } catch (e) { erg = { fehler: 'Im Shop lief etwas schief: ' + (e?.message || e) }; }
  if (typ === 'test') { if (tab.eigen) chrome.tabs.remove(tab.id).catch(() => {}); return erg; }
  // Bestellen: Warenkorb neu laden (zeigt die neuen Artikel) und auf die Bestätigungsseite warten
  chrome.tabs.reload(tab.id).catch(() => {});
  if (erg.ok?.length && daten.lauf) {
    const offen = (await ladeListe(SHOP_OFFEN)).filter((o) => o.lauf !== daten.lauf && Date.now() - o.am < 7 * 864e5);
    offen.push({ lauf: daten.lauf, lieferant_id: daten.lieferant_id, basis: a.shop_url.replace(/\/+$/, ''), muster: a.bestaetigung || '/checkout/onepage/success', am: Date.now() });
    await speichereListe(SHOP_OFFEN, offen);
  }
  return erg;
}

// Bestätigungsseite erkennen: jeder Tab des Shops, dessen Adresse das Muster enthält
chrome.tabs.onUpdated.addListener(async (_id, info, tab) => {
  if (info.status !== 'complete' || !tab.url) return;
  const offen = await ladeListe(SHOP_OFFEN);
  const treffer = offen.filter((o) => tab.url.startsWith(o.basis) && tab.url.includes(o.muster));
  if (!treffer.length) return;
  await speichereListe(SHOP_OFFEN, offen.filter((o) => !treffer.includes(o)));
  const best = await ladeListe(SHOP_BESTAETIGT);
  treffer.forEach((t) => best.push({ lauf: t.lauf, lieferant_id: t.lieferant_id, am: new Date().toISOString() }));
  await speichereListe(SHOP_BESTAETIGT, best);
  const kg = await chrome.tabs.query({ url: ['https://knechtgarten.com/*', 'https://www.knechtgarten.com/*'] });
  kg.forEach((t) => chrome.tabs.sendMessage(t.id, { kg: 'shopEreignis', typ: 'bestaetigt' }).catch(() => {}));
});

chrome.runtime.onMessage.addListener((msg, _sender, antwort) => {
  if (msg?.kg !== 'shopAuftrag' || !['bestellen', 'test', 'bestaetigungen', 'quittieren'].includes(msg.typ)) return;
  shopAuftrag(msg.typ, msg.daten).then(antwort).catch((e) => antwort({ fehler: String(e?.message || e) }));
  return true;
});
