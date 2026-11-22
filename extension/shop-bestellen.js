// ============================================================================
// QR-Bestellung: Artikel in den Warenkorb eines Lieferanten-Shops legen (läuft in background.js).
// Pro Shop-System ein Ablauf (heute: Magento = Aquasolar, Dabag = B-TEAM + IMMER AG, Hybris = HGC, PrestaShop = MIDAS; Magento auch Aqua-Technik). Was sich ändern kann (Shop-Adresse, Sprache,
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
  const basis = a.shop_url.replace(/\/+$/, ''), url = basis + STARTSEITE[a.plattform](a);
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
  const P = sprache ? '/' + sprache : '';   // Sprache im Pfad (Aquasolar /de), ohne bei Aqua-Technik
  const acc = await fetch(`${P}/customer/account/`, { credentials: 'include' });
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
    const html = await fetch(`${P}/checkout/cart/`, { credentials: 'include' }).then((r) => r.text());
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
    const r = await post(`${P}/checkout/cart/add/`, { product: String(id), qty: String(p.menge) }).catch(() => null);
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
  if (Object.keys(upd).length) await post(`${P}/checkout/cart/updatePost/`, { update_cart_action: 'update_qty', ...upd }).catch(() => null);
  return { ok, fehler };
}
// ---------- Dabag (B-TEAM, IMMER AG): Direkterfassung im Warenkorb, Notiz ins Feld «Kommission» ----------
async function dabagAblauf(auftrag, pos, _sprache, opt) {
  const c = opt && opt.firmenkorb ? 1 : 0;
  const nrn = [...new Set(pos.map((p) => String(p.nr)))];
  const korbHtml = () => fetch('/?srv=basket&companyYN=' + c, { credentials: 'include' }).then((r) => r.text());
  const h0 = await korbHtml();
  if (!/srv=logout/.test(h0)) return { fehler: 'Im Shop nicht angemeldet. Bitte im Shop anmelden und nochmals starten.' };
  const lesen = (html) => {
    const d = new DOMParser().parseFromString(html, 'text/html');
    return [...d.querySelectorAll('tr[id^="bsi-"]')].filter((t) => /^bsi-\d+$/.test(t.id)).map((t) => {
      const id = t.id.slice(4), text = t.textContent || '';
      const nr = nrn.find((n) => new RegExp('(^|[^0-9A-Za-z])' + n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '([^0-9A-Za-z]|$)').test(text)) || null;
      const m = d.querySelector(`[name="menge_${id}"]`), k = d.querySelector(`[name="bsiKommission_${id}"]`);
      return { id, nr, menge: m ? parseFloat(m.value) || 0 : 0, kommentar: k ? k.value : null };
    });
  };
  // Test: nur Anmeldung + Warenkorb lesbar (die Suche zeigt den Suchbegriff immer an, taugt nicht zum Prüfen der Nummern)
  if (auftrag === 'test') return { eingeloggt: true, nurLogin: true, gefunden: [], fehlt: [] };
  const summe = (wk, nr) => wk.filter((w) => w.nr === nr).reduce((s, w) => s + w.menge, 0);
  const vorher = lesen(h0), fehler = [], gesendet = [], angepasst = [], mitKommission = new Set();
  // Variante 1 (B-TEAM): Direkterfassung im Warenkorb. Variante 2 (IMMER AG, ohne Direkterfassung): Artikelnummer suchen
  // (springt auf die Artikelseite), Zeile mit genau dieser Nummer → Knopf «In den Warenkorb» (rpc_basket_item_add), Kommission gleich mit.
  const direkt = /pg=fastadd/.test(h0);
  for (const p of pos) {
    let r = null;
    if (direkt) {
      r = await fetch('/?srv=basket&pg=fastadd&companyYN=' + c, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ txtArtNr_free: String(p.nr), txtMenge_free: String(p.menge) }) }).catch(() => null);
    } else {
      const s = await fetch('/?srv=search&q=' + encodeURIComponent(p.nr), { credentials: 'include' }).then((x) => x.text()).catch(() => '');
      const d = new DOMParser().parseFromString(s, 'text/html');
      const zeile = [...d.querySelectorAll('tr')].find((t) => t.querySelector('[id^="btn_"]') && [...t.querySelectorAll('a,td,span')].some((e) => e.textContent.trim() === String(p.nr)));
      if (!zeile) { fehler.push({ nr: p.nr, grund: 'im Shop nicht gefunden' }); continue; }
      const gid = zeile.querySelector('[id^="btn_"]').id.slice(4), qi = zeile.querySelector('[id^="quantity_"]');
      // Verpackungseinheit (Schritt): auf ganze Packungen aufrunden und melden
      const schritt = qi ? parseFloat(qi.getAttribute('step')) || 1 : 1;
      let menge = p.menge;
      if (schritt > 1 && menge % schritt) { menge = Math.ceil(menge / schritt) * schritt; angepasst.push({ nr: p.nr, menge, schritt }); }
      r = await fetch(`/pagesshop/rpc/rpc_basket_item_add.cfm?id=${gid}&quantity=${menge}&laenge=0&unit=0&kommission=${encodeURIComponent(String(p.notiz || '').slice(0, 100))}&zubehoerYN=0`,
        { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: '' }).catch(() => null);
      if (p.notiz) mitKommission.add(String(p.nr));
    }
    if (!r || !r.ok) { fehler.push({ nr: p.nr, grund: 'Shop-Fehler ' + (r ? r.status : '') }); continue; }
    gesendet.push(p);
  }
  const nachher = lesen(await korbHtml()), ok = [];
  for (const p of gesendet) {
    if (summe(nachher, String(p.nr)) > summe(vorher, String(p.nr))) ok.push(p.nr);
    else fehler.push({ nr: p.nr, grund: 'im Shop nicht gefunden oder nicht im Warenkorb gelandet' });
  }
  for (const p of gesendet.filter((x) => x.notiz && ok.includes(x.nr) && !mitKommission.has(String(x.nr)))) {
    const w = nachher.find((x) => x.nr === String(p.nr) && x.kommentar === '');
    if (w) await fetch(`/pagespartner/rpc/rpc_basket_item_commission_upd.cfm?companyYN=${c}&bsiId=${w.id}`, { method: 'POST', credentials: 'include',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ ['bsiKommission_' + w.id]: String(p.notiz).slice(0, 100) }) }).catch(() => null);
  }
  return { ok, fehler, angepasst };
}

// ---------- Hybris / SAP Commerce (HGC): Shop-eigene Schnittstelle /<sprache>/api/… mit CSRF-Token aus <meta name="_csrf"> ----------
async function hybrisAblauf(auftrag, pos, sprache) {
  const L = sprache || 'de';
  const tok = document.querySelector('meta[name="_csrf"]')?.content;
  if (window.initialData?.app?.isloggedIn === false) return { fehler: 'Im Shop nicht angemeldet. Bitte im Shop anmelden und nochmals starten.' };
  if (!tok) return { fehler: 'Shop-Seite nicht bereit (Sicherheits-Token fehlt).' };
  const hdr = { Accept: 'application/json', 'Content-Type': 'application/json', 'X-Requested-With': 'XMLHttpRequest', CSRFToken: tok };
  const korb = async () => { const j = await fetch(`/${L}/api/cart`, { headers: hdr, credentials: 'include' }).then((r) => r.json()).catch(() => null); return j?.data?.cart?.entries || []; };
  const produkt = async (nr) => { const r = await fetch(`/${L}/api/product/${encodeURIComponent(nr)}`, { headers: hdr, credentials: 'include' }).catch(() => null);
    if (!r || !r.ok) return null; const j = await r.json().catch(() => null); return j?.data?.product?.code ? j.data.product : null; };
  if (auftrag === 'test') {
    const gefunden = [], fehlt = [];
    for (const p of pos) (await produkt(p.nr) ? gefunden : fehlt).push(p.nr);
    return { eingeloggt: true, gefunden, fehlt };
  }
  const summe = (wk, code) => wk.filter((w) => w.product?.code === code).reduce((s, w) => s + (+w.quantity || 0), 0);
  const vorher = await korb(), fehler = [], gesendet = [], angepasst = [];
  for (const p of pos) {
    const pr = await produkt(p.nr);
    if (!pr) { fehler.push({ nr: p.nr, grund: 'im Shop nicht gefunden' }); continue; }
    const einheit = pr.orderUnit?.code || pr.baseUnit?.code || 'PCE';
    const faktor = (pr.quantityUnits || []).find((q) => q.unit?.code === einheit)?.roundingUnitFactor || 1;
    let menge = p.menge;
    if (faktor > 1 && menge % faktor) { menge = Math.ceil(menge / faktor) * faktor; angepasst.push({ nr: p.nr, menge, schritt: faktor }); }
    const r = await fetch(`/${L}/api/cart-entry`, { method: 'POST', headers: hdr, credentials: 'include',
      body: JSON.stringify({ rawQuantity: menge, unitCode: einheit, product: { code: pr.code, name: pr.name }, commissionId: '' }) }).catch(() => null);
    const j = r ? await r.json().catch(() => null) : null;
    const err = j?.messages?.ERROR?.[0]?.message;
    if (!r || !r.ok || err) { fehler.push({ nr: p.nr, grund: err || 'Shop-Fehler ' + (r ? r.status : '') }); continue; }
    gesendet.push({ ...p, code: pr.code });
  }
  const nachher = await korb(), ok = [];
  for (const p of gesendet) {
    if (summe(nachher, p.code) > summe(vorher, p.code)) ok.push(p.nr);
    else fehler.push({ nr: p.nr, grund: 'nicht im Warenkorb gelandet' });
  }
  return { ok, fehler, angepasst };
}

// ---------- PrestaShop (MIDAS): Suche liefert JSON mit Referenz, Warenkorb über ajax-Aufruf mit static_token ----------
async function prestashopAblauf(auftrag, pos, sprache) {
  // leerer Warenkorb leitet auf die Startseite um: warten, bis die Shop-Seite bereit ist
  for (let i = 0; i < 40 && !(window.prestashop && window.prestashop.static_token); i++) await new Promise((r) => setTimeout(r, 250));
  const ps = window.prestashop, P = sprache ? '/' + sprache : '';
  if (!ps || !ps.static_token) return { fehler: 'Shop-Seite nicht bereit (Sicherheits-Token fehlt).' };
  if (!(ps.customer && ps.customer.is_logged)) return { fehler: 'Im Shop nicht angemeldet. Bitte im Shop anmelden und nochmals starten.' };
  const hdr = { Accept: 'application/json, text/javascript, */*; q=0.01', 'X-Requested-With': 'XMLHttpRequest', 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' };
  const sucheUrl = ps.urls?.pages?.search || P + '/suche', korbUrl = ps.urls?.pages?.cart || P + '/warenkorb';
  const finde = async (nr) => {
    const j = await fetch(sucheUrl + (sucheUrl.includes('?') ? '&' : '?') + 'controller=search&s=' + encodeURIComponent(nr), { headers: hdr, credentials: 'include' }).then((r) => r.json()).catch(() => null);
    return (j?.products || []).find((p) => String(p.reference || '').trim().toLowerCase() === String(nr).trim().toLowerCase()) || null;
  };
  if (auftrag === 'test') {
    const gefunden = [], fehlt = [];
    for (const p of pos) (await finde(p.nr) ? gefunden : fehlt).push(p.nr);
    return { eingeloggt: true, gefunden, fehlt };
  }
  const summe = (produkte, nr) => (produkte || []).filter((x) => String(x.reference || '').toLowerCase() === String(nr).toLowerCase()).reduce((s, x) => s + (+x.quantity || 0), 0);
  const vorher = ps.cart?.products || [], fehler = [], angepasst = [], ok = [];
  for (const p of pos) {
    const pr = await finde(p.nr);
    if (!pr) { fehler.push({ nr: p.nr, grund: 'im Shop nicht gefunden' }); continue; }
    let menge = p.menge; const min = +pr.minimal_quantity || 1;
    if (menge < min) { menge = min; angepasst.push({ nr: p.nr, menge, schritt: min }); }
    const r = await fetch(korbUrl, { method: 'POST', headers: hdr, credentials: 'include', body: new URLSearchParams({ token: ps.static_token, id_product: String(pr.id_product),
      id_product_attribute: String(pr.id_product_attribute || 0), id_customization: '0', qty: String(menge), add: '1', action: 'update', ajax: '1' }) }).catch(() => null);
    const j = r ? await r.json().catch(() => null) : null;
    if (!j || !j.success) { fehler.push({ nr: p.nr, grund: (j && [].concat(j.errors || []).join(' ')) || 'Shop-Fehler ' + (r ? r.status : '') }); continue; }
    if (summe(j.cart?.products, p.nr) > summe(vorher, p.nr)) ok.push(p.nr); else fehler.push({ nr: p.nr, grund: 'nicht im Warenkorb gelandet' });
  }
  return { ok, fehler, angepasst };
}

const ABLAEUFE = { magento: magentoAblauf, dabag: dabagAblauf, hybris: hybrisAblauf, prestashop: prestashopAblauf };
// Seite, die beim Start im Shop-Tab geöffnet wird (Warenkorb)
const STARTSEITE = {
  magento: (a) => (a.sprache ? '/' + a.sprache : '') + '/checkout/cart/',
  dabag: (a) => '/?srv=basket&companyYN=' + (a.optionen?.firmenkorb ? 1 : 0),
  hybris: (a) => `/${a.sprache || 'de'}/cart`,
  prestashop: (a) => (a.sprache ? '/' + a.sprache : '') + (a.optionen?.warenkorb || '/warenkorb'),
};

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
      args: [typ === 'test' ? 'test' : 'bestellen', daten.positionen || [], a.sprache || '', a.optionen || {}] });
    erg = r?.result || { fehler: 'Keine Antwort vom Shop.' };
  } catch (e) { erg = { fehler: 'Im Shop lief etwas schief: ' + (e?.message || e) }; }
  if (typ === 'test') { if (tab.eigen) chrome.tabs.remove(tab.id).catch(() => {}); return erg; }
  // Bestellen: Warenkorb neu laden (zeigt die neuen Artikel) und auf die Bestätigungsseite warten
  chrome.tabs.reload(tab.id).catch(() => {});
  if (erg.ok?.length && daten.lauf && a.bestaetigung) {   // ohne bekannte Bestätigungsseite keine Erkennung (nur «Ist schon bestellt?»)
    const offen = (await ladeListe(SHOP_OFFEN)).filter((o) => o.lauf !== daten.lauf && Date.now() - o.am < 7 * 864e5);
    offen.push({ lauf: daten.lauf, lieferant_id: daten.lieferant_id, basis: a.shop_url.replace(/\/+$/, ''), muster: a.bestaetigung, am: Date.now() });
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
