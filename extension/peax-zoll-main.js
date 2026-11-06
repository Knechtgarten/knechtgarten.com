// ============================================================================
// Zoll in PEAX – Teil in der Seite selbst (world: MAIN).
//
// Merkt sich die Anmelde-Header, die PEAX bei seinen eigenen Anfragen an
// proxy.peax.ch mitschickt (Authorization, X-Workspace-Id, actor_/context_*),
// und führt im Auftrag von peax-zoll.js aus:
//   1. Volltextsuche nach der Zollanmeldungsnummer (26CHEI…)
//   2. die passende Rechnung bestimmen (Typ INVOICE, keine «vv…»-Dokumente)
//   3. die Verfügung als PDF hinten anhängen (PEAX-Funktion «PDF am Ende
//      hinzufügen», beobachtet 2026-11-06):
//      POST /core-service-pdf/api/v1/object-contents/{id}/page-manipulation/insert
//      FormData file=PDF, data={"pageIndexes":[Seitenzahl]} → 204, sofort gespeichert
// Kann bei einem Umbau von PEAX brechen – dann meldet es einen Fehler, hängt
// aber nie etwas Falsches an.
// ============================================================================
(function () {
  const API = 'https://proxy.peax.ch';
  const H = {};
  const KANAL = 'kg-zoll';

  // Header aus PEAX' eigenen Anfragen merken (nur im Speicher dieser Seite)
  const setH = XMLHttpRequest.prototype.setRequestHeader;
  XMLHttpRequest.prototype.setRequestHeader = function (k, v) {
    if (/^(authorization|x-workspace-id|actor_account_|context_account_)/i.test(k)) H[k] = v;
    return setH.apply(this, arguments);
  };

  const bereit = async (ms = 30000) => { const t = Date.now(); while (!H.Authorization && Date.now() - t < ms) await new Promise((r) => setTimeout(r, 300)); return !!H.Authorization; };
  const peax = async (pfad, opt = {}) => {
    const r = await fetch(API + pfad, { ...opt, headers: { ...H, Accept: 'application/json', ...(opt.headers || {}) } });
    if (!r.ok && r.status !== 204) throw new Error('PEAX ' + r.status + ' bei ' + pfad.split('?')[0]);
    return r;
  };

  // Seitenzahl eines PDF: mit PEAX' pdf.js, sonst aus dem PDF selbst (/Count im Seitenbaum, auch in Objekt-Streams)
  async function seiten(buf) {
    try { if (window.pdfjsLib?.getDocument) { const d = await window.pdfjsLib.getDocument({ data: buf.slice(0) }).promise; return d.numPages; } } catch (_) { /* weiter unten */ }
    const u8 = new Uint8Array(buf), raw = new TextDecoder('latin1').decode(u8), zahlen = [];
    const sammeln = (t) => { const rx = /\/Count\s+(\d+)/g; let k; while ((k = rx.exec(t))) zahlen.push(+k[1]); };
    sammeln(raw);
    let pos = 0;
    while ((pos = raw.indexOf('/ObjStm', pos)) >= 0) {
      let s = raw.indexOf('stream', pos); s = raw.indexOf('\n', s) + 1; const e = raw.indexOf('endstream', s); if (s <= 0 || e < 0) break;
      try { const rd = new Blob([u8.slice(s, e)]).stream().pipeThrough(new DecompressionStream('deflate')).getReader(); let t = ''; const dec = new TextDecoder('latin1');
        try { for (;;) { const { done, value } = await rd.read(); if (done) break; t += dec.decode(value, { stream: true }); } } catch (_) {}
        sammeln(t); } catch (_) {}
      pos = e;
    }
    const n = Math.max(0, ...zahlen);
    if (!n) throw new Error('Seitenzahl der Rechnung nicht lesbar');
    return n;
  }

  async function anhaengen({ zanr, url, dateiname }) {
    if (!(await bereit())) return { ergebnis: 'fehler', hinweis: 'PEAX-Anmeldung nicht erkannt' };
    // 1. Suche
    const s = await (await peax('/core-feature-search/search-api/api/v1/search', { method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ filter: [{ path: 'inboxType', op: 'isEqualTo', value: 'SEARCH' }], search: zanr }) })).json();
    const ids = (s?.documents?.items || []).slice(0, 15);
    // 2. nur Rechnungen, keine abgelegten Verfügungen
    const kand = [];
    for (const id of ids) {
      try { const d = await (await peax('/document/api/v3/document/' + id)).json();
        if (d?.type === 'INVOICE' && !/^vv/i.test(d.title || '') && !d.bin) kand.push({ id, titel: d.title || '', sender: d.sender?.name || '' }); } catch (_) {}
    }
    if (!kand.length) return { ergebnis: 'nicht_gefunden', hinweis: 'Keine Rechnung mit ' + zanr + ' in PEAX' };
    if (kand.length > 1) return { ergebnis: 'mehrdeutig', hinweis: kand.length + ' Rechnungen: ' + kand.map((k) => k.titel).join(', ') };
    const ziel = kand[0];
    // 3. Seitenzahl der Rechnung, Verfügung holen, hinten anhängen
    const pdf = await (await peax('/core-feature-media/api/v1/media/document/' + ziel.id, { headers: { Accept: 'application/pdf' } })).arrayBuffer();
    const n = await seiten(pdf);
    const evv = await fetch(url); if (!evv.ok) throw new Error('Verfügung nicht ladbar');
    const fd = new FormData();
    fd.append('file', new Blob([await evv.arrayBuffer()], { type: 'application/pdf' }), dateiname || ('vvmwst_' + zanr + '.pdf'));
    fd.append('data', JSON.stringify({ pageIndexes: [n] }));
    await peax('/core-service-pdf/api/v1/object-contents/' + ziel.id + '/page-manipulation/insert', { method: 'POST', body: fd });
    return { ergebnis: 'angehaengt', peax_doc_id: ziel.id, peax_titel: (ziel.sender ? ziel.sender + ' · ' : '') + ziel.titel };
  }

  window.addEventListener('message', async (e) => {
    if (e.source !== window || e.data?.kanal !== KANAL || e.data.typ !== 'auftrag') return;
    let antwort;
    try { antwort = await anhaengen(e.data.evv); } catch (err) { antwort = { ergebnis: 'fehler', hinweis: String(err?.message || err).slice(0, 200) }; }
    window.postMessage({ kanal: KANAL, typ: 'antwort', nr: e.data.nr, antwort }, '*');
  });
})();
