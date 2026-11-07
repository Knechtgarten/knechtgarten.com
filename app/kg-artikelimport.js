/* ============================================================================
   kg-artikelimport.js – Artikel aus Liste oder Bild (Artikelstamm)
   Ein Fenster, zwei Arten:
     KAI.oeffnen({ sb, modus: 'neu' })     → nur neue Artikel anlegen (bestehende grau «existiert schon»)
     KAI.oeffnen({ sb, modus: 'preise' })  → nur Preise bestehender Artikel nachführen (alt → neu, ±%)
   Weitere Angaben: lieferantId (Vorauswahl), vonHand (Funktion → Reiter «Von Hand»), fertig (nach dem Speichern).
   Lesen macht die Edge Function «artikel-import» (Claude): Bild, PDF, Excel/CSV (hier zu Text) oder Text.
   VP Knecht wird gleich berechnet wie im Artikelstamm (Marge bzw. VP Lieferant + Zuschlag, gestufte Rundung),
   alte Einkaufspreise landen im Preisverlauf (artikel_preis_verlauf).
   ============================================================================ */
(function(){
  const I = (n, s = 14) => window.KG ? KG.icon(n, s) : '';
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const zahl = v => { if(v == null || v === '') return null; const n = parseFloat(String(v).replace(/'/g, '').replace(',', '.')); return isNaN(n) ? null : n; };
  const fmt = n => n == null ? '–' : Number(n).toLocaleString('de-CH', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const norm = s => String(s ?? '').toLowerCase().replace(/[\s\-_.\/]/g, '');
  const rundeVp = roh => { const schritt = roh <= 5 ? 0.1 : roh <= 20 ? 0.5 : 1; return Math.round(Math.round(roh / schritt) * schritt * 100) / 100; };

  const CSS = `
.kai-ovl{position:fixed;inset:0;background:rgba(35,43,53,.45);display:flex;align-items:center;justify-content:center;z-index:65;}
.kai-box{background:#fff;border-radius:12px;width:min(1080px,calc(100vw - 32px));max-height:90vh;display:flex;flex-direction:column;box-shadow:0 12px 40px rgba(0,0,0,.25);
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;font-size:13px;color:#232B35;}
.kai-kopf{display:flex;align-items:center;gap:14px;padding:16px 20px 0;}
.kai-titel{font-size:15px;font-weight:700;color:#323E4E;}
.kai-reiter{display:flex;gap:2px;background:#F5F7F9;border:1px solid #E1E5E9;border-radius:8px;padding:2px;}
.kai-reiter[hidden]{display:none;}
.kai-reiter button{all:unset;cursor:pointer;padding:5px 12px;border-radius:6px;font-size:12.5px;font-weight:600;color:#6B7079;}
.kai-reiter button.on{background:#fff;color:#323E4E;box-shadow:0 1px 2px rgba(35,43,53,.12);}
.kai-zu{margin-left:auto;}
.kai-inhalt{padding:14px 20px;overflow:auto;flex:1;min-height:0;}
.kai-zeile{display:flex;flex-wrap:wrap;gap:10px;align-items:flex-end;margin-bottom:12px;}
.kai-fld{display:flex;flex-direction:column;gap:4px;min-width:0;max-width:100%;}
.kai-fld[hidden]{display:none;}
.kai-fld label{font-size:10.5px;font-weight:700;color:#6B7079;text-transform:uppercase;letter-spacing:.03em;}
.kai-fld select,.kai-fld input,.kai-inhalt textarea{font:inherit;font-size:12.5px;border:1px solid #E1E5E9;border-radius:6px;padding:7px 9px;color:#232B35;background:#fff;}
.kai-fld input.kurz{width:70px;}
.kai-drop{border:1.5px dashed #C9CED4;border-radius:10px;padding:18px;text-align:center;color:#6B7079;cursor:pointer;background:#FAFBFC;}
.kai-drop.aktiv{border-color:#323E4E;background:#F5F7F9;}
.kai-drop b{color:#323E4E;}
.kai-datei{display:inline-flex;align-items:center;gap:6px;margin-top:8px;background:#EEF1F4;border-radius:6px;padding:3px 6px 3px 10px;font-size:12px;color:#323E4E;}
.kai-hinweis{width:100%;box-sizing:border-box;margin-top:10px;}
.kai-status{font-size:12px;color:#6B7079;min-height:16px;margin:8px 0;}
.kai-status.err{color:#B3261E;}
.kai-tab{width:100%;border-collapse:collapse;font-size:12.5px;}
.kai-tab th{text-align:left;font-size:10.5px;font-weight:700;color:#6B7079;text-transform:uppercase;letter-spacing:.03em;padding:6px 6px;border-bottom:1px solid #E1E5E9;position:sticky;top:-14px;background:#fff;}
.kai-tab td{padding:4px 6px;border-bottom:1px solid #F0F2F4;vertical-align:middle;}
.kai-tab td.r,.kai-tab th.r{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums;}
.kai-tab input[type=text]{font:inherit;font-size:12.5px;border:1px solid transparent;border-radius:5px;padding:4px 6px;width:100%;box-sizing:border-box;background:transparent;}
.kai-tab input[type=text]:hover,.kai-tab input[type=text]:focus{border-color:#E1E5E9;background:#fff;outline:none;}
.kai-tab input.zahl{text-align:right;width:90px;}
.kai-tab tr.grau td{color:#9AA0A7;}
.kai-tab tr.grau input{color:#9AA0A7;}
.kai-tag{font-size:10px;font-weight:700;border-radius:5px;padding:1px 6px;background:#EEF1F4;color:#6B7079;white-space:nowrap;}
.kai-tag.s1{background:#D6E7F4;color:#323E4E;}
.kai-tag.s2{background:#F4E7E6;color:#B3261E;}
.kai-gruppe{display:flex;align-items:center;gap:10px;margin:18px 0 6px;font-size:12px;font-weight:700;color:#323E4E;}
.kai-gruppe .kai-link{all:unset;cursor:pointer;font-weight:600;color:#6B7079;text-decoration:underline;}
.kai-fuss{display:flex;flex-wrap:wrap;align-items:center;gap:10px;padding:12px 20px;border-top:1px solid #E1E5E9;}
.kai-fuss .kai-info{font-size:12px;color:#6B7079;margin-right:auto;}
.kai-btn{all:unset;box-sizing:border-box;cursor:pointer;display:inline-flex;align-items:center;gap:6px;height:32px;padding:0 14px;border-radius:7px;font-size:12.5px;font-weight:600;border:1px solid #E1E5E9;background:#fff;color:#323E4E;}
.kai-btn.haupt{background:#323E4E;border-color:#323E4E;color:#fff;}
.kai-btn:disabled{opacity:.45;cursor:default;}
.kai-btn.klein{height:24px;padding:0 9px;font-size:11.5px;}
`;
  // Stil gleich beim Laden: die Reiter «Von Hand | Aus Liste oder Bild» braucht auch das Artikel-Fenster der Seite
  if(!document.getElementById('kai-stil')){ const st = document.createElement('style'); st.id = 'kai-stil'; st.textContent = CSS; document.head.appendChild(st); }

  window.KAI = { oeffnen };

  async function oeffnen(opt){
    const sb = opt.sb;
    const modus = opt.modus === 'preise' ? 'preise' : 'neu';
    const z = { lieferanten: [], kurse: {}, warn: { stufe1_prozent: 10, stufe2_prozent: 25 }, einheiten: [], bestand: [], gelesen: null, dateien: [], zeigeFehlend: false };

    const ovl = document.createElement('div');
    ovl.className = 'kai-ovl';
    ovl.innerHTML = `<div class="kai-box" role="dialog" aria-modal="true">
      <div class="kai-kopf">
        ${modus === 'neu' && opt.vonHand
          ? `<span class="kai-titel">Neuer Artikel</span><div class="kai-reiter"><button type="button" data-r="hand">Von Hand</button><button type="button" class="on">Aus Liste oder Bild</button></div>`
          : `<span class="kai-titel">${modus === 'neu' ? 'Artikel aus Liste oder Bild' : 'Preisabgleich'}</span>`}
        <button type="button" class="kg-ibtn kai-zu" title="Schliessen" aria-label="Schliessen">${I('x', 14)}</button>
      </div>
      <div class="kai-inhalt">
        <div class="kai-zeile">
          <div class="kai-fld"><label>Lieferant</label><select data-f="lief"></select></div>
          ${modus === 'neu' ? `<div class="kai-fld"><label>Kategorie</label><select data-f="kat"><option value="material">Material</option><option value="personal">Personal</option><option value="maschine">Maschine</option><option value="logistik">Logistik</option></select></div>` : ''}
          <div class="kai-fld"><label>Preise in der Liste</label><select data-f="art"><option value="ep">Einkauf netto</option><option value="liste">Listenpreis</option></select></div>
          <div class="kai-fld" data-w="rabatt" hidden><label>Rabatt %</label><input type="text" class="kurz" data-f="rabatt" inputmode="decimal" autocomplete="off" data-form-type="other"></div>
          <div class="kai-fld"><label>MwSt</label><select data-f="mwst"><option value="0">ohne MwSt</option><option value="1">inkl. MwSt</option></select></div>
        </div>
        <div class="kai-drop" tabindex="0">${I('upload', 18)}<div style="margin-top:4px;"><b>Bild, PDF, Excel oder Text</b> hierher ziehen, einfügen (Strg+V) oder <b>auswählen</b></div>
          <div class="kai-dateien"></div></div>
        <input type="file" hidden multiple accept="image/*,.pdf,.xlsx,.xls,.csv,.txt" data-f="datei">
        <textarea class="kai-hinweis" rows="2" data-f="hinweis" placeholder="Hinweis für die KI (optional), z. B. «nur Seite 3», «Preise pro 100 Stk.», «nur Pflanzen» – oder hier Text aus einer Mail einfügen"></textarea>
        <div class="kai-zeile" style="margin:10px 0 0;"><button type="button" class="kai-btn haupt" data-act="lesen">Lesen</button></div>
        <div class="kai-status"></div>
        <div class="kai-ergebnis"></div>
      </div>
      <div class="kai-fuss"><span class="kai-info"></span><button type="button" class="kai-btn" data-act="zu">Abbrechen</button><button type="button" class="kai-btn haupt" data-act="speichern" disabled>${modus === 'neu' ? 'Artikel anlegen' : 'Preise übernehmen'}</button></div>
    </div>`;
    document.body.appendChild(ovl);
    const q = s => ovl.querySelector(s);
    const f = n => q(`[data-f="${n}"]`);
    const status = (t, err) => { q('.kai-status').textContent = t || ''; q('.kai-status').classList.toggle('err', !!err); };
    const schliessen = () => { ovl.remove(); document.removeEventListener('paste', onPaste); document.removeEventListener('keydown', onKey); };
    const onKey = e => { if(e.key === 'Escape') schliessen(); };
    document.addEventListener('keydown', onKey);
    q('.kai-zu').onclick = schliessen; q('[data-act="zu"]').onclick = schliessen;
    if(q('[data-r="hand"]')) q('[data-r="hand"]').onclick = () => { schliessen(); opt.vonHand(); };

    // Stammdaten
    const [lf, wk, ws, eh] = await Promise.all([
      sb.from('lieferant').select('id,name,kuerzel,archiviert_am,lieferant_datenabgleich(minimum_marge_prozent,mwst_satz,mwst_inklusive,waehrung,vp_lieferant_gleich_vp_knecht,zuschlag_prozent,kategorie_default)').is('archiviert_am', null).order('name'),
      sb.from('wechselkurs').select('waehrung,kurs_zu_chf'),
      sb.from('preisabgleich_warnstufen').select('*').eq('id', true).maybeSingle(),
      sb.from('einheit').select('code')
    ]);
    z.lieferanten = (lf.data || []).map(l => ({ ...l, da: Array.isArray(l.lieferant_datenabgleich) ? l.lieferant_datenabgleich[0] || {} : l.lieferant_datenabgleich || {} }));
    (wk.data || []).forEach(w => z.kurse[w.waehrung] = w.kurs_zu_chf);
    if(ws.data) z.warn = ws.data;
    z.einheiten = (eh.data || []).map(e => e.code);
    f('lief').innerHTML = '<option value="">– wählen –</option>' + z.lieferanten.map(l => `<option value="${l.id}">${esc(l.name)}${l.kuerzel ? ' (' + esc(l.kuerzel) + ')' : ''}</option>`).join('');
    const lieferant = () => z.lieferanten.find(l => l.id === f('lief').value);
    const lieferantGewaehlt = () => {
      const l = lieferant(); z.bestand = [];
      if(l){ f('mwst').value = l.da.mwst_inklusive ? '1' : '0'; if(f('kat')) f('kat').value = l.da.kategorie_default || 'material'; }
      if(z.gelesen) zeigen();
    };
    f('lief').onchange = lieferantGewaehlt;
    if(opt.lieferantId){ f('lief').value = opt.lieferantId; lieferantGewaehlt(); }
    f('art').onchange = () => { q('[data-w="rabatt"]').hidden = f('art').value !== 'liste'; if(z.gelesen) zeigen(); };
    [f('rabatt'), f('mwst')].forEach(el => el.addEventListener(el.tagName === 'SELECT' ? 'change' : 'input', () => { if(z.gelesen) zeigen(); }));

    // Dateien: ziehen, einfügen, auswählen
    const drop = q('.kai-drop');
    const dateienZeigen = () => {
      q('.kai-dateien').innerHTML = z.dateien.map((d, i) => `<span class="kai-datei">${esc(d.name)}<button type="button" class="kg-ibtn" data-weg="${i}" title="Entfernen">${I('x', 12)}</button></span>`).join(' ');
      q('.kai-dateien').querySelectorAll('[data-weg]').forEach(b => b.onclick = e => { e.stopPropagation(); z.dateien.splice(+b.dataset.weg, 1); dateienZeigen(); });
    };
    const dazu = list => { for(const d of list) z.dateien.push(d); dateienZeigen(); };
    drop.onclick = () => f('datei').click();
    f('datei').onchange = () => { dazu([...f('datei').files]); f('datei').value = ''; };
    drop.ondragover = e => { e.preventDefault(); drop.classList.add('aktiv'); };
    drop.ondragleave = () => drop.classList.remove('aktiv');
    drop.ondrop = e => { e.preventDefault(); drop.classList.remove('aktiv'); dazu([...e.dataTransfer.files]); };
    const onPaste = e => {
      const files = [...(e.clipboardData?.files || [])];
      if(files.length){ e.preventDefault(); dazu(files.map((d, i) => d.name && d.name !== 'image.png' ? d : new File([d], `Eingefügtes Bild ${z.dateien.length + i + 1}.png`, { type: d.type }))); }
    };
    document.addEventListener('paste', onPaste);

    q('[data-act="lesen"]').onclick = lesen;
    q('[data-act="speichern"]').onclick = () => modus === 'neu' ? anlegen() : preiseUebernehmen();

    // ------------------------------------------------------------------ Lesen
    async function lesen(){
      const l = lieferant();
      if(!l){ status('Bitte zuerst den Lieferanten wählen.', true); return; }
      const hinweis = f('hinweis').value.trim();
      if(!z.dateien.length && !hinweis){ status('Bitte eine Datei hineinziehen oder Text einfügen.', true); return; }
      const teile = [];
      try {
        for(const d of z.dateien) teile.push(...await teileAus(d));
      } catch(e){ status(e.message, true); return; }
      // ohne Datei: der eingefügte Text ist der Inhalt
      if(!z.dateien.length) teile.push({ text: hinweis, name: 'Text' });
      const hinweisKi = z.dateien.length ? hinweis : '';
      q('[data-act="lesen"]').disabled = true;
      let fertig = 0; const alle = [], fehler = [];
      status(`Lese ${teile.length > 1 ? teile.length + ' Teile' : ''} … (kann bei langen Listen eine Minute dauern)`);
      const arbeit = teile.slice();
      await Promise.all([0, 1, 2].map(async () => {
        while(arbeit.length){
          const t = arbeit.shift();
          const { data, error } = await sb.functions.invoke('artikel-import', { body: { ...t, name: undefined, hinweis: hinweisKi, lieferant: l.name } });
          let msg = data?.error || null;
          if(error){ msg = error.message; try { const b = await error.context?.json(); if(b?.error) msg = b.error; } catch(_){} }
          if(msg) fehler.push(`${t.name}: ${msg}`); else alle.push(...(data.artikel || []));
          fertig++; if(teile.length > 1) status(`Gelesen ${fertig} von ${teile.length} …`);
        }
      }));
      q('[data-act="lesen"]').disabled = false;
      // doppelte Zeilen (gleiche Nummer bzw. Bezeichnung) nur einmal
      const gesehen = new Set();
      z.gelesen = alle.filter(a => { const k = a.nr ? 'n' + norm(a.nr) : 'b' + norm(a.bezeichnung); if(gesehen.has(k)) return false; gesehen.add(k); return true; })
        .map(a => ({ ...a, einheit: einheitCode(a.einheit), an: true }));
      status(fehler.length ? 'Nicht alles lesbar: ' + fehler.join(' · ') : (z.gelesen.length ? '' : 'Keine Artikel gefunden.'), !!fehler.length);
      await zeigen();
    }

    function einheitCode(e){ const k = z.einheiten.find(c => c.toLowerCase() === String(e || '').toLowerCase()); return k || e || 'Stk.'; }

    // Datei → Teile für die KI (Bilder verkleinert, Excel/CSV als Text in Stücken)
    async function teileAus(d){
      const n = d.name || 'Datei';
      if(d.type.startsWith('image/')) return [{ bild: await bildKlein(d), name: n }];
      if(d.type === 'application/pdf' || /\.pdf$/i.test(n)){
        if(d.size > 25e6) throw new Error(n + ' ist zu gross (max. 25 MB).');
        return [{ pdf: await base64(d), name: n }];
      }
      if(/\.(xlsx|xls|csv)$/i.test(n)){
        if(!window.XLSX) await skript('https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js');
        const wb = XLSX.read(await d.arrayBuffer(), { type: 'array' });
        const out = [];
        wb.SheetNames.forEach(s => {
          const zeilen = XLSX.utils.sheet_to_csv(wb.Sheets[s], { FS: ';', blankrows: false }).split('\n').filter(z => z.replace(/;/g, '').trim());
          if(!zeilen.length) return;
          const kopf = zeilen[0];
          for(let i = 1; i < zeilen.length || i === 1; i += 200) out.push({ text: (wb.SheetNames.length > 1 ? 'Blatt ' + s + '\n' : '') + kopf + '\n' + zeilen.slice(i, i + 200).join('\n'), name: `${n} ${s} ab Zeile ${i}` });
        });
        return out;
      }
      const text = await d.text();
      const out = [];
      for(let i = 0; i < text.length; i += 30000) out.push({ text: text.slice(i, i + 30000), name: n });
      return out;
    }
    const base64 = d => new Promise((ok, nok) => { const r = new FileReader(); r.onload = () => ok(String(r.result).split(',')[1]); r.onerror = nok; r.readAsDataURL(d); });
    const skript = src => new Promise((ok, nok) => { const s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = () => nok(new Error('Excel-Leser nicht ladbar.')); document.head.appendChild(s); });
    async function bildKlein(d){
      const url = URL.createObjectURL(d);
      try {
        const img = await new Promise((ok, nok) => { const i = new Image(); i.onload = () => ok(i); i.onerror = () => nok(new Error((d.name || 'Bild') + ' nicht lesbar.')); i.src = url; });
        const m = Math.min(1, 2000 / Math.max(img.width, img.height));
        const c = document.createElement('canvas'); c.width = Math.round(img.width * m); c.height = Math.round(img.height * m);
        const g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height); g.drawImage(img, 0, 0, c.width, c.height);
        return c.toDataURL('image/jpeg', 0.9);
      } finally { URL.revokeObjectURL(url); }
    }

    // ------------------------------------------------------- Preise umrechnen
    // Preis aus der Liste → { ep, vp } (netto, ohne MwSt). Listenpreis mit Rabatt ergibt den Einkauf.
    function preise(p){
      if(p == null) return { ep: null, vp: null };
      const l = lieferant() || { da: {} };
      let netto = f('mwst').value === '1' ? p / (1 + (l.da.mwst_satz ?? 8.1) / 100) : p;
      netto = Math.round(netto * 100) / 100;
      if(f('art').value === 'ep') return { ep: netto, vp: null };
      const r = zahl(f('rabatt').value);
      return { ep: r != null ? Math.round(netto * (1 - r / 100) * 100) / 100 : null, vp: netto };
    }
    function vpKnecht(a){
      const da = (lieferant() || { da: {} }).da;
      const kurs = !a.waehrung || a.waehrung === 'CHF' ? 1 : (z.kurse[a.waehrung] ?? 1);
      if(da.vp_lieferant_gleich_vp_knecht){
        if(a.vp_lieferant == null || a.vp_lieferant <= 0) return null;
        const b = a.vp_lieferant * kurs; return rundeVp(da.zuschlag_prozent ? b * (1 + da.zuschlag_prozent / 100) : b);
      }
      if(a.ep_lieferant == null) return null;
      const m = da.minimum_marge_prozent;
      if(m == null || m >= 100) return null;
      return rundeVp(a.ep_lieferant * kurs / (1 - m / 100));
    }

    async function bestandLaden(){
      const l = lieferant(); if(!l) return [];
      if(z.bestand.lid === l.id) return z.bestand;
      const alle = [];
      for(let von = 0; ; von += 1000){
        const { data, error } = await sb.from('artikel').select('id,artikelnummer_lieferant,bezeichnung,einheit,ep_lieferant,vp_lieferant,vp_knecht,waehrung,preis_gesperrt').eq('lieferant_id', l.id).order('bezeichnung').range(von, von + 999);
        if(error){ status(error.message, true); break; }
        alle.push(...data); if(data.length < 1000) break;
      }
      alle.lid = l.id; z.bestand = alle; return alle;
    }
    function finde(bestand, a){
      if(a.nr){ const n = norm(a.nr); const t = bestand.find(b => norm(b.artikelnummer_lieferant) === n); if(t) return t; }
      const b = norm(a.bezeichnung); return bestand.find(x => norm(x.bezeichnung) === b) || null;
    }

    // ------------------------------------------------------------- Anzeigen
    async function zeigen(){
      const bestand = await bestandLaden();
      const el = q('.kai-ergebnis');
      if(!z.gelesen || !z.gelesen.length){ el.innerHTML = ''; knopf(0); return; }
      z.gelesen.forEach(a => { a.treffer = finde(bestand, a); a.p = preise(a.preis); });
      if(modus === 'neu') zeigenNeu(el); else zeigenPreise(el, bestand);
    }
    function knopf(n, text){
      const b = q('[data-act="speichern"]'); b.disabled = !n;
      b.textContent = n ? text : (modus === 'neu' ? 'Artikel anlegen' : 'Preise übernehmen');
    }
    // Spalte «Einkauf» bzw. «Neu» nur, wenn der Listenpreis umgerechnet wird (MwSt oder Listenpreis/Rabatt)
    const umgerechnet = () => f('art').value !== 'ep' || f('mwst').value === '1';
    const eingabe = (a, feld, cls = '') => `<input type="text" class="${cls}" data-feld="${feld}" value="${esc(feld === 'preis' ? (a.preis ?? '') : a[feld])}" autocomplete="off" data-form-type="other">`;
    function binden(el, liste){
      el.querySelectorAll('tr[data-i]').forEach(tr => {
        const a = liste[+tr.dataset.i];
        tr.querySelectorAll('[data-feld]').forEach(inp => inp.addEventListener('change', () => {
          a[inp.dataset.feld] = inp.dataset.feld === 'preis' ? zahl(inp.value) : inp.value.trim();
          zeigen();
        }));
        const cb = tr.querySelector('input[type=checkbox]');
        if(cb) cb.addEventListener('change', () => { a.an = cb.checked; zeigen(); });
      });
    }

    function zeigenNeu(el){
      const l = lieferant();
      const neu = z.gelesen.filter(a => !a.treffer && a.an).length;
      const da = z.gelesen.filter(a => a.treffer).length;
      el.innerHTML = `<table class="kai-tab"><thead><tr><th style="width:24px;"></th><th style="width:130px;">Nr. Lieferant</th><th>Bezeichnung</th><th style="width:80px;">Einheit</th><th class="r">Preis Liste</th>${umgerechnet() ? '<th class="r">Einkauf</th>' : ''}<th class="r">VP Knecht</th></tr></thead><tbody>
        ${z.gelesen.map((a, i) => {
          const vk = vpKnecht({ ep_lieferant: a.p.ep, vp_lieferant: a.p.vp, waehrung: l?.da.waehrung || 'CHF' });
          return a.treffer
            ? `<tr class="grau" data-i="${i}"><td></td><td>${esc(a.nr)}</td><td>${esc(a.bezeichnung)}</td><td>${esc(a.einheit)}</td><td class="r">${fmt(a.preis)}</td><td class="r" colspan="${umgerechnet() ? 2 : 1}"><span class="kai-tag">existiert schon</span></td></tr>`
            : `<tr data-i="${i}"><td><input type="checkbox" ${a.an ? 'checked' : ''}></td><td>${eingabe(a, 'nr')}</td><td>${eingabe(a, 'bezeichnung')}</td><td>${eingabe(a, 'einheit')}</td><td class="r">${eingabe(a, 'preis', 'zahl')}</td>${umgerechnet() ? `<td class="r">${fmt(a.p.ep)}</td>` : ''}<td class="r">${fmt(vk)}</td></tr>`;
        }).join('')}</tbody></table>`;
      binden(el, z.gelesen);
      q('.kai-info').textContent = `${z.gelesen.length} gelesen` + (da ? ` · ${da} existieren schon` : '');
      knopf(neu, `${neu} Artikel anlegen`);
    }

    function tag(alt, neu){
      if(alt == null || neu == null || !alt) return '';
      const pz = (neu - alt) / alt * 100, b = Math.abs(pz);
      const s = b >= (z.warn.stufe2_prozent ?? 25) ? ' s2' : b >= (z.warn.stufe1_prozent ?? 10) ? ' s1' : '';
      return `<span class="kai-tag${s}">${pz >= 0 ? '+' : ''}${pz.toFixed(1)}%</span>`;
    }
    // Vergleich auf dem Einkauf; bei Listenpreis ohne Rabatt auf dem VP Lieferant
    const vergleich = a => a.p.ep != null ? ['ep_lieferant', a.p.ep] : ['vp_lieferant', a.p.vp];
    function zeigenPreise(el, bestand){
      const treffer = z.gelesen.filter(a => a.treffer && a.preis != null);
      const geaendert = treffer.filter(a => { const [feld, neu] = vergleich(a); return neu != null && neu !== a.treffer[feld]; });
      const gleich = treffer.length - geaendert.length;
      const neuBeim = z.gelesen.filter(a => !a.treffer);
      const getroffen = new Set(treffer.map(a => a.treffer.id));
      const fehlend = bestand.filter(b => !getroffen.has(b.id));
      const n = geaendert.filter(a => a.an).length;
      el.innerHTML = `
        <div class="kai-gruppe" style="margin-top:0;">Preis geändert (${geaendert.length})${gleich ? `<span style="font-weight:400;color:#6B7079;">· ${gleich} unverändert</span>` : ''}</div>
        ${geaendert.length ? `<table class="kai-tab"><thead><tr><th style="width:24px;"></th><th style="width:130px;">Nr. Lieferant</th><th>Bezeichnung</th><th class="r">Bisher</th><th class="r">Liste</th>${umgerechnet() ? '<th class="r">Neu</th>' : ''}<th class="r"></th><th class="r">VP Knecht</th></tr></thead><tbody>
          ${geaendert.map(a => {
            const i = z.gelesen.indexOf(a), t = a.treffer, [feld, neu] = vergleich(a);
            const nachher = { ...t, [feld]: neu, ...(a.p.vp != null && feld !== 'vp_lieferant' ? { vp_lieferant: a.p.vp } : {}) };
            const vk = t.preis_gesperrt ? t.vp_knecht : vpKnecht(nachher);
            return `<tr data-i="${i}"><td><input type="checkbox" ${a.an ? 'checked' : ''}></td><td>${esc(t.artikelnummer_lieferant)}</td><td>${esc(t.bezeichnung)}${feld === 'vp_lieferant' ? ' <span class="kai-tag">Listenpreis</span>' : ''}</td>
              <td class="r">${fmt(t[feld])}</td><td class="r">${eingabe(a, 'preis', 'zahl')}</td>${umgerechnet() ? `<td class="r">${fmt(neu)}</td>` : ''}<td class="r">${tag(t[feld], neu)}</td>
              <td class="r">${t.preis_gesperrt ? `<span title="VP Knecht gesperrt">${I('lock', 12)}</span> ` : ''}${fmt(t.vp_knecht)}${!t.preis_gesperrt && vk !== t.vp_knecht ? ' → ' + fmt(vk) : ''}</td></tr>`;
          }).join('')}</tbody></table>` : '<div style="color:#6B7079;font-size:12px;">Keine geänderten Preise.</div>'}
        ${neuBeim.length ? `<div class="kai-gruppe">Neu beim Lieferanten (${neuBeim.length}) <button type="button" class="kai-btn klein" data-act="alleNeu">${I('plus', 12)} Alle anlegen</button></div>
          <table class="kai-tab"><tbody>${neuBeim.map(a => `<tr data-i="${z.gelesen.indexOf(a)}"><td style="width:130px;">${esc(a.nr)}</td><td>${esc(a.bezeichnung)}</td><td style="width:70px;">${esc(a.einheit)}</td><td class="r">${fmt(a.preis)}</td>
            <td class="r" style="width:90px;"><button type="button" class="kai-btn klein" data-neu="${z.gelesen.indexOf(a)}">${I('plus', 12)} Anlegen</button></td></tr>`).join('')}</tbody></table>` : ''}
        ${fehlend.length ? `<div class="kai-gruppe">Nicht in der Liste (${fehlend.length}) <button type="button" class="kai-link" data-act="fehlend">${z.zeigeFehlend ? 'ausblenden' : 'zeigen'}</button></div>
          ${z.zeigeFehlend ? `<table class="kai-tab"><tbody>${fehlend.map(b => `<tr class="grau"><td style="width:130px;">${esc(b.artikelnummer_lieferant)}</td><td>${esc(b.bezeichnung)}</td><td class="r">${fmt(b.ep_lieferant)}</td></tr>`).join('')}</tbody></table>` : ''}` : ''}`;
      binden(el, z.gelesen);
      el.querySelectorAll('[data-neu]').forEach(b => b.onclick = async () => { b.disabled = true; await neuAnlegen([z.gelesen[+b.dataset.neu]]); });
      if(q('[data-act="alleNeu"]')) q('[data-act="alleNeu"]').onclick = async () => { q('[data-act="alleNeu"]').disabled = true; await neuAnlegen(neuBeim); };
      if(q('[data-act="fehlend"]')) q('[data-act="fehlend"]').onclick = () => { z.zeigeFehlend = !z.zeigeFehlend; zeigen(); };
      q('.kai-info').textContent = `${z.gelesen.length} gelesen · ${treffer.length} gefunden`;
      knopf(n, `${n} Preise übernehmen`);
    }

    // ------------------------------------------------------------ Speichern
    async function neuAnlegen(liste){
      const l = lieferant(); if(!l || !liste.length) return 0;
      const kat = f('kat')?.value || l.da.kategorie_default || 'material';
      const waehrung = l.da.waehrung || 'CHF';
      const zeilen = liste.map(a => {
        const p = preise(a.preis);
        const z1 = {
          bezeichnung: a.bezeichnung, artikelnummer_lieferant: a.nr || null,
          artikelnummer_knecht: a.nr ? `${l.kuerzel}_${a.nr}` : null,
          lieferant_id: l.id, kategorie: kat, einheit: a.einheit || 'Stk.',
          ep_lieferant: p.ep, vp_lieferant: p.vp, waehrung,
          mwst_satz_pct: l.da.mwst_satz ?? 8.1, sync_easybill: true
        };
        const vk = vpKnecht(z1); if(vk != null) z1.vp_knecht = vk;
        return z1;
      });
      status('Lege an …');
      const { data, error } = await sb.from('artikel').insert(zeilen).select('id,ep_lieferant');
      if(error){ status(error.message, true); return 0; }
      const verlauf = data.filter(d => d.ep_lieferant != null).map(d => ({ artikel_id: d.id, alter_preis: null, neuer_preis: d.ep_lieferant, quelle: 'abgleich', methode: 'preisliste', lieferant_id: l.id }));
      if(verlauf.length) await sb.from('artikel_preis_verlauf').insert(verlauf);
      await sb.from('lieferant_datenabgleich').upsert({ lieferant_id: l.id, letzter_schnellimport_zeitpunkt: new Date().toISOString() }, { onConflict: 'lieferant_id' });
      z.bestand = [];
      status(`${data.length} Artikel angelegt.`);
      opt.fertig?.();
      await zeigen();
      return data.length;
    }
    async function anlegen(){
      const liste = z.gelesen.filter(a => !a.treffer && a.an && a.bezeichnung);
      q('[data-act="speichern"]').disabled = true;
      const n = await neuAnlegen(liste);
      if(n) { schliessen(); window.showToast?.(`${n} Artikel angelegt.`); }
    }
    async function preiseUebernehmen(){
      const l = lieferant();
      const liste = z.gelesen.filter(a => a.an && a.treffer && a.preis != null).filter(a => { const [feld, neu] = vergleich(a); return neu != null && neu !== a.treffer[feld]; });
      if(!liste.length) return;
      q('[data-act="speichern"]').disabled = true;
      status('Übernehme Preise …');
      let ok = 0; const fehler = [], verlauf = [];
      for(const a of liste){
        const t = a.treffer, upd = {};
        if(a.p.ep != null) upd.ep_lieferant = a.p.ep;
        if(a.p.vp != null) upd.vp_lieferant = a.p.vp;
        if(!t.preis_gesperrt){ const vk = vpKnecht({ ...t, ...upd }); if(vk != null) upd.vp_knecht = vk; }
        const { error } = await sb.from('artikel').update(upd).eq('id', t.id);
        if(error){ fehler.push(t.bezeichnung + ': ' + error.message); continue; }
        ok++;
        if(upd.ep_lieferant != null && upd.ep_lieferant !== t.ep_lieferant)
          verlauf.push({ artikel_id: t.id, alter_preis: t.ep_lieferant, neuer_preis: upd.ep_lieferant, quelle: 'abgleich', methode: 'preisliste', lieferant_id: l.id });
      }
      if(verlauf.length) await sb.from('artikel_preis_verlauf').insert(verlauf);
      await sb.from('lieferant_datenabgleich').upsert({ lieferant_id: l.id, letzter_abgleich_zeitpunkt: new Date().toISOString(), letzter_abgleich_status: 'ok' }, { onConflict: 'lieferant_id' });
      opt.fertig?.();
      if(fehler.length){ status(fehler.join(' · '), true); z.bestand = []; await zeigen(); return; }
      schliessen(); window.showToast?.(`${ok} Preise übernommen.`);
    }
  }
})();
