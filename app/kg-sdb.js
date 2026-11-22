// ============================================================================
// kg-sdb.js – Sicherheitsdatenblatt-Kleber für Kanister (gelbes laminiertes P-touch-Band 36 mm, z. B. TZe-661)
//
//   await KGS.code(sb, eintrag)            sorgt für wissen_eintrag.sdb_code (geheimer Zufallscode) und gibt ihn zurück
//   KGS.html(p, g)                         ein Kleber; p = { titel, ufi, code }, g = 'S' | 'M' | 'L'
//   KGS.vorschau(p, g)                     Kleber für die Bildschirm-Vorschau (gelb hinterlegt wie das Band)
//   KGS.drucken([{ titel, ufi, code, anzahl }], g)   Druckdialog, alle Kleber als eine Serie (P-touch schneidet ab)
//
// QR → knechtgarten.com/s/<code> (sdb-qr.html, ohne Anmeldung): Produkt, Notfall Tox Info 145 mit UFI, Datenblatt.
// Grössen wie bei den Maschinen-Klebern: S 50 / M 80 / L 120 mm, Rand oben/unten 4.5 mm. Braucht qrcode-generator.
// ============================================================================
(function () {
  const BASIS = 'https://knechtgarten.com/s/', GR = { S: 50, M: 80, L: 120 };
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const zufall = () => { const z = 'abcdefghjkmnpqrstuvwxyz23456789', a = crypto.getRandomValues(new Uint8Array(16)); return [...a].map(b => z[b % z.length]).join(''); };

  async function code(sb, e) {
    if (e.sdb_code) return e.sdb_code;
    const c = zufall();
    const { error } = await sb.from('wissen_eintrag').update({ sdb_code: c }).eq('id', e.id);
    if (error) throw new Error('Code konnte nicht gespeichert werden: ' + error.message);
    e.sdb_code = c; return c;
  }

  function qr(text, mm) {
    try { const q = qrcode(0, 'M'); q.addData(text); q.make(); const n = q.getModuleCount(); let d = '';
      for (let r = 0; r < n; r++) for (let c = 0; c < n; c++) if (q.isDark(r, c)) d += `M${c} ${r}h1v1h-1z`;
      return `<svg width="${mm}mm" height="${mm}mm" viewBox="0 0 ${n} ${n}" shape-rendering="crispEdges"><path d="${d}" fill="#000"/></svg>`;
    } catch (_) { return ''; }
  }

  const CSS = `
    .sk{height:36mm;display:flex;align-items:center;gap:3mm;padding:4.5mm 3mm;color:#000;box-sizing:border-box;overflow:hidden;font-family:Arial,Helvetica,sans-serif;flex:none;}
    .sk.s-S{width:50mm;} .sk.s-M{width:80mm;} .sk.s-L{width:120mm;}
    .sk .q{flex:none;line-height:0;}
    .sk .t{min-width:0;flex:1;height:100%;display:flex;flex-direction:column;gap:.8mm;}
    .sk .art{font-size:7pt;font-weight:700;letter-spacing:.06em;text-transform:uppercase;}
    .sk .n{font-weight:700;line-height:1.1;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow-wrap:break-word;}
    .sk .f{margin-top:auto;border-top:.3mm solid #000;padding-top:.8mm;line-height:1.25;font-weight:700;}
    .s-M .n{font-size:13pt;} .s-M .f{font-size:7.5pt;}
    .s-L .art{font-size:8pt;} .s-L .n{font-size:20pt;} .s-L .f{font-size:9pt;white-space:nowrap;}
    .sk .hoch{writing-mode:vertical-rl;transform:rotate(180deg);height:100%;min-width:0;flex:1;display:flex;flex-direction:column;justify-content:center;gap:.8mm;}
    .s-S .n{font-size:10.5pt;} .s-S .k{font-size:7pt;font-weight:700;white-space:nowrap;}`;

  function html(p, g = 'M') {
    const q = `<div class="q">${qr(BASIS + p.code, 26)}</div>`, n = esc(p.titel);
    if (g === 'S') return `<div class="sk s-S">${q}<div class="hoch" lang="de-CH"><div class="n">${n}</div><div class="k">Sicherheitsdatenblatt</div></div></div>`;
    if (g === 'L') return `<div class="sk s-L">${q}<div class="t" lang="de-CH"><div class="art">Sicherheitsdatenblatt · Scannen</div><div class="n">${n}</div>
      <div class="f">Notfall Tox Info Suisse 145${p.ufi ? ' · UFI ' + esc(p.ufi) : ''}</div></div></div>`;
    return `<div class="sk s-M">${q}<div class="t" lang="de-CH"><div class="art">Sicherheitsdatenblatt</div><div class="n">${n}</div><div class="f">Notfall Tox Info 145</div></div></div>`;
  }
  function vorschau(p, g) {
    if (!document.getElementById('kgs-css')) { const st = document.createElement('style'); st.id = 'kgs-css'; st.textContent = CSS + '.sk.vor{background:#FFE15A;border-radius:1.5mm;box-shadow:0 0 0 1px rgba(0,0,0,.12);}'; document.head.appendChild(st); }
    return html(p, g).replace('class="sk ', 'class="sk vor ');
  }

  // Druck über einen unsichtbaren Rahmen, eine Seite pro Kleber (P-touch: «Automatisch schneiden»)
  function drucken(liste, g = 'M') {
    const kleber = liste.flatMap(p => Array.from({ length: Math.max(1, Math.min(50, p.anzahl | 0 || 1)) }, () => html(p, g)));
    if (!kleber.length) return;
    document.getElementById('kgsFrame')?.remove();
    const f = document.createElement('iframe'); f.id = 'kgsFrame';
    f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden';
    document.body.appendChild(f);
    const d = f.contentDocument; d.open();
    d.write(`<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Sicherheitsdatenblatt-Kleber</title><style>
      @page{size:${GR[g]}mm 36mm;margin:0;} html,body{margin:0;padding:0;} ${CSS}
      .sk{break-after:page;page-break-after:always;} .sk:last-child{break-after:auto;page-break-after:auto;}</style></head><body>${kleber.join('')}</body></html>`);
    d.close();
    setTimeout(() => { f.contentWindow.focus(); f.contentWindow.print(); }, 300);
  }

  window.KGS = { code, html, vorschau, drucken, GR, BASIS };
})();
