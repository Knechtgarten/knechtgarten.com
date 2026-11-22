// ============================================================================
// kg-artikelkleber.js – QR-Kleber für Artikel im Lager (Artikelstamm, P-touch-Band 36 mm, S 50 / M 80 / L 120 mm)
//
//   KGA.fenster(sb, artikel[], lieferantName(id))   Fenster: Grösse, Anzahl, (bei einem Artikel) Datenblatt-Produkt, Vorschau, Drucken
//
// QR → knechtgarten.com/a/<artikel.qr_code> (artikel-qr.html, ohne Anmeldung): Artikel, Nummer, Lieferant, und – wenn
// mit einem Produkt im Nachschlagewerk verknüpft (artikel.wissen_eintrag_id) – das Sicherheitsdatenblatt.
// Layout wie im Muster: S Text hochkant, M Name + Linie «Art.-Nr. · Lieferant», L Name gross. Braucht qrcode-generator.
// ============================================================================
(function () {
  const BASIS = 'https://knechtgarten.com/a/', GR = { S: 50, M: 80, L: 120 };
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const zufall = () => { const z = 'abcdefghjkmnpqrstuvwxyz23456789', a = crypto.getRandomValues(new Uint8Array(16)); return [...a].map(b => z[b % z.length]).join(''); };
  const nummer = a => a.artikelnummer_lieferant || a.artikelnummer_knecht || '';

  function qr(text, mm) {
    try { const q = qrcode(0, 'M'); q.addData(text); q.make(); const n = q.getModuleCount(); let d = '';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
      return `<svg width="${mm}mm" height="${mm}mm" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges"><path d="${d}" fill="#000"/></svg>`;
    } catch (_) { return ''; }
  }
  const CSS = `
    .ak{height:36mm;display:flex;align-items:center;gap:3mm;padding:4.5mm 3mm;color:#000;background:#fff;box-sizing:border-box;overflow:hidden;font-family:Arial,Helvetica,sans-serif;flex:none;}
    .ak.a-S{width:50mm;} .ak.a-M{width:80mm;} .ak.a-L{width:120mm;}
    .ak .q{flex:none;line-height:0;}
    .ak .t{min-width:0;flex:1;height:100%;display:flex;flex-direction:column;gap:.8mm;}
    .ak .n{font-weight:700;line-height:1.1;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow-wrap:break-word;}
    .ak .u{line-height:1.2;}
    .ak .f{margin-top:auto;border-top:.3mm solid #000;padding-top:.8mm;line-height:1.25;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;}
    .a-M .n{font-size:12pt;} .a-M .f{font-size:7.5pt;}
    .a-L .n{font-size:19pt;} .a-L .u{font-size:9pt;} .a-L .f{font-size:8.5pt;}
    .ak .hoch{writing-mode:vertical-rl;transform:rotate(180deg);height:100%;min-width:0;flex:1;display:flex;flex-direction:column;justify-content:center;gap:.8mm;}
    .a-S .n{font-size:10pt;} .a-S .k{font-size:7pt;font-weight:700;white-space:nowrap;}`;

  function html(a, g, liefName) {
    const q = `<div class="q">${qr(BASIS + a.qr_code, 26)}</div>`, n = esc(a.bezeichnung), nr = nummer(a), lf = liefName(a.lieferant_id) || '';
    if (g === 'S') return `<div class="ak a-S">${q}<div class="hoch" lang="de-CH"><div class="n">${n}</div>${nr ? `<div class="k">Art.-Nr. ${esc(nr)}</div>` : ''}</div></div>`;
    const fuss = [nr && `Art.-Nr. <b>${esc(nr)}</b>`, lf && esc(lf)].filter(Boolean).join(' · ');
    if (g === 'L') return `<div class="ak a-L">${q}<div class="t" lang="de-CH"><div class="n">${n}</div>${a.einheit ? `<div class="u">Einheit: ${esc(a.einheit)}</div>` : ''}<div class="f">${fuss}</div></div></div>`;
    return `<div class="ak a-M">${q}<div class="t" lang="de-CH"><div class="n">${n}</div><div class="f">${fuss}</div></div></div>`;
  }

  function drucken(liste, g, anzahl, liefName) {
    const kleber = liste.flatMap(a => Array.from({ length: Math.max(1, Math.min(50, anzahl | 0 || 1)) }, () => html(a, g, liefName)));
    document.getElementById('kgaFrame')?.remove();
    const f = document.createElement('iframe'); f.id = 'kgaFrame';
    f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden';
    document.body.appendChild(f);
    const d = f.contentDocument; d.open();
    d.write(`<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Artikel-Kleber</title><style>@page{size:${GR[g]}mm 36mm;margin:0;} html,body{margin:0;padding:0;} ${CSS}
      .ak{break-after:page;page-break-after:always;} .ak:last-child{break-after:auto;page-break-after:auto;}</style></head><body>${kleber.join('')}</body></html>`);
    d.close();
    setTimeout(() => { f.contentWindow.focus(); f.contentWindow.print(); }, 300);
  }

  async function fenster(sb, artikel, liefName) {
    if (!artikel.length) return;
    if (!document.getElementById('kga-css')) { const st = document.createElement('style'); st.id = 'kga-css'; st.textContent = CSS + `
      .kga-sch{position:fixed;inset:0;background:rgba(35,43,53,.4);z-index:300;display:flex;align-items:flex-start;justify-content:center;padding:60px 16px 16px;overflow:auto;}
      .kga{background:#fff;border-radius:12px;width:min(640px,100%);box-shadow:0 18px 50px rgba(20,28,38,.3);padding:18px;display:flex;flex-direction:column;gap:12px;color:#232B35;font-size:13px;}
      .kga h3{margin:0;font-size:16px;color:#323E4E;} .kga .hin{color:#6B7079;font-size:12px;}
      .kga .reihe{display:flex;gap:10px;align-items:flex-end;flex-wrap:wrap;} .kga label{display:flex;flex-direction:column;gap:3px;font-size:12px;color:#4C5C70;font-weight:600;}
      .kga input,.kga select{height:32px;border:1px solid #D5DBE1;border-radius:7px;padding:0 8px;font:inherit;font-size:13px;}
      .kga .vor{background:#F5F7F9;border-radius:10px;padding:12px;overflow-x:auto;} .kga .vor .ak{box-shadow:0 0 0 1px #D5DBE1;border-radius:1.5mm;}
      .kga .kn{display:flex;gap:8px;justify-content:flex-end;} .kga .kga-ab{background:#fff!important;color:#323E4E!important;border:1px solid #D5DBE1!important;}`; document.head.appendChild(st); }
    let g = (() => { try { return localStorage.getItem('kgArtKleberGr') || 'M'; } catch (_) { return 'M'; } })(), anzahl = 1;
    // Produkte mit Sicherheitsdatenblatt (nur bei einem einzelnen Artikel zum Verknüpfen)
    let produkte = [];
    if (artikel.length === 1) {
      const { data: d } = await sb.from('wissen_datei').select('eintrag_id').eq('bereich', 'sdb').is('exemplar_id', null);
      const ids = [...new Set((d || []).map(x => x.eintrag_id))];
      if (ids.length) { const { data: e } = await sb.from('wissen_eintrag').select('id,titel').in('id', ids).is('archiviert_am', null).order('titel'); produkte = e || []; }
    }
    const w = document.createElement('div'); w.className = 'kga-sch';
    const zeichnen = () => {
      const a0 = { ...artikel[0], qr_code: artikel[0].qr_code || 'vorschauvorschau' };
      w.innerHTML = `<div class="kga" role="dialog" aria-label="QR-Kleber"><h3>QR-Kleber · ${artikel.length === 1 ? esc(artikel[0].bezeichnung) : artikel.length + ' Artikel'}</h3>
        <div class="kg-seg" role="group" aria-label="Grösse">${Object.entries(GR).map(([k, mm]) => `<button type="button" data-g="${k}" class="${k === g ? 'on' : ''}">${k} · ${mm} mm</button>`).join('')}</div>
        <div class="vor">${html(a0, g, liefName)}</div>
        <div class="reihe"><label>Anzahl${artikel.length > 1 ? ' pro Artikel' : ''}<input type="number" min="1" max="50" id="kgaAnz" value="${anzahl}" style="width:90px"></label>
          ${artikel.length === 1 ? `<label style="flex:1;min-width:220px">Sicherheitsdatenblatt von Produkt <span style="font-weight:400;color:#8B9097">optional</span><select id="kgaSdb"><option value="">– keines –</option>${produkte.map(p => `<option value="${p.id}"${p.id === artikel[0].wissen_eintrag_id ? ' selected' : ''}>${esc(p.titel)}</option>`).join('')}</select></label>` : ''}</div>
        <div class="hin">P-touch-Band 36 mm, beim Drucken den P-touch wählen, Grösse 100 %. Der QR öffnet ohne Anmeldung den Artikel${artikel.length === 1 ? ' und, falls gewählt, das Sicherheitsdatenblatt' : ''}. Später kommt dort «Nachbestellen» dazu, ohne neue Kleber.</div>
        <div class="kn"><button type="button" class="btn kga-ab" data-zu>Abbrechen</button><button type="button" class="btn" data-druck>Drucken${artikel.length > 1 ? ` (${artikel.length * anzahl} Kleber)` : ''}</button></div></div>`;
    };
    zeichnen(); document.body.appendChild(w);
    const zu = () => { w.remove(); removeEventListener('keydown', esc_); };
    const esc_ = e => { if (e.key === 'Escape') zu(); }; addEventListener('keydown', esc_);
    w.addEventListener('change', async e => {
      if (e.target.id === 'kgaAnz') { anzahl = Math.max(1, Math.min(50, +e.target.value || 1)); zeichnen(); }
      if (e.target.id === 'kgaSdb') { const v = e.target.value || null; const { error } = await sb.from('artikel').update({ wissen_eintrag_id: v }).eq('id', artikel[0].id); if (!error) artikel[0].wissen_eintrag_id = v; }
    });
    w.addEventListener('click', async e => {
      if (e.target === w || e.target.closest('[data-zu]')) return zu();
      const gb = e.target.closest('[data-g]'); if (gb) { g = gb.dataset.g; try { localStorage.setItem('kgArtKleberGr', g); } catch (_) {} return zeichnen(); }
      if (e.target.closest('[data-druck]')) {
        for (const a of artikel) if (!a.qr_code) { const c = zufall(); const { error } = await sb.from('artikel').update({ qr_code: c }).eq('id', a.id); if (error) return alert('QR-Code konnte nicht gespeichert werden: ' + error.message); a.qr_code = c; }
        drucken(artikel, g, anzahl, liefName); zu();
      }
    });
  }

  window.KGA = { fenster, html, GR };
})();
