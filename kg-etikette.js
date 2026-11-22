// ============================================================================
// kg-etikette.js – Adressetiketten drucken (gemeinsam für alle Tools)
//
//   KGE.verbinden(sb)                         Supabase-Client der Seite (für die Einstellungen)
//   await KGE.drucken({ an: [...], anzahl })  Druckdialog mit 1 bis n gleichen Etiketten
//   KGE.zeilen(adresse)                       { firma, name, vorname, nachname, zusatz1, zusatz2, strasse, plz, ort, land } → Zeilen
//   KGE.html(an, einst, anzahl)               fertiges HTML (Vorschau in Einstellungen › Etiketten)
//
// Einstellungen (Einstellungen › Allgemein › Etiketten, app_einstellung 'etiketten'):
//   { breite: 102, hoehe: 51, absender: ['Knecht AG Naturnahe Gärten', 'Badhaus 42', '3615 Heimenschwand'] }
// Standard 102 × 51 mm quer (Brother QL-1110NWB, vorgestanzte Rolle DK-11240). Absender hochkant links, Empfänger rechts.
// Auf einem normalen Drucker kommt die Etikette in Originalgrösse oben links aufs A4-Blatt (zum Testen).
// Der Browser zeigt immer den Druckdialog; Chrome merkt sich den zuletzt gewählten Drucker.
// ============================================================================
(function () {
  const STANDARD = { breite: 102, hoehe: 51, absender: ['Knecht AG Naturnahe Gärten', 'Badhaus 42', '3615 Heimenschwand'] };
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  let sb = null, einst = null;

  function verbinden(client) { sb = client; einst = null; }
  async function laden(neu) {
    if (einst && !neu) return einst;
    einst = { ...STANDARD };
    try { if (sb) { const { data } = await sb.from('app_einstellung').select('wert').eq('schluessel', 'etiketten').maybeSingle();
      if (data?.wert) { const w = JSON.parse(data.wert); einst = { ...STANDARD, ...w, absender: (w.absender || []).filter(Boolean).length ? w.absender.filter(Boolean) : STANDARD.absender }; } } } catch (_) {}
    return einst;
  }

  function zeilen(a = {}) {
    const person = [a.vorname, a.nachname].filter(Boolean).join(' ');
    const z = [a.firma || '', a.firma ? person : (person || a.name || ''), a.zusatz1, a.zusatz2, a.strasse, [a.plz, a.ort].filter(Boolean).join(' ')];
    if (a.land && !/^(ch|schweiz|switzerland|suisse|svizzera)$/i.test(String(a.land).trim())) z.push(String(a.land).toUpperCase());
    return z.map(s => String(s || '').trim()).filter(Boolean).filter((s, i, l) => l.indexOf(s) === i);
  }

  // Quer: links Absender hochkant (von unten nach oben lesbar), rechts der Empfänger über die ganze Höhe zentriert.
  // Schrift wächst mit der Etikettenhöhe, bei vielen Zeilen etwas kleiner.
  function html(an, e = einst || STANDARD, anzahl = 1) {
    const B = +e.breite || 102, H = +e.hoehe || 51, abs = e.absender || STANDARD.absender;
    const gr = Math.max(8, Math.min(16, H * 0.245)) * (an.length > 4 ? 0.85 : 1), vg = Math.max(6, Math.min(10, H * 0.165));   // Absender: bei 51 mm Höhe ca. 8.4 pt
    const eine = `<div class="et"><div class="von">${abs.map((s, i) => i === 0 ? `<b>${esc(s)}</b>` : `<span>${esc(s)}</span>`).join('')}</div>
      <div class="an">${an.map((s, i) => `<div class="z${i === 0 ? ' n' : ''}${i === an.length - 1 && /^\d{4,5}\s/.test(s) ? ' ort' : ''}">${esc(s)}</div>`).join('')}</div></div>`;
    return `<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Etikette</title><style>
      @page { size: ${B}mm ${H}mm; margin: 0; }
      * { box-sizing: border-box; }
      html, body { margin: 0; padding: 0; }
      @media screen { html, body { overflow: hidden; } }
      body { font-family: Arial, Helvetica, sans-serif; color: #000; }
      .et { width: ${B}mm; height: ${H}mm; padding: 3mm 4mm 3mm 3mm; display: flex; overflow: hidden; page-break-after: always; break-after: page; }
      .et:last-child { page-break-after: auto; break-after: auto; }
      .von { width: ${(abs.length * vg * 0.45 + 2.5).toFixed(1)}mm; flex: none; writing-mode: vertical-rl; transform: rotate(180deg); font-size: ${vg.toFixed(1)}pt; line-height: 1.25;
        display: flex; flex-direction: column; justify-content: center; text-align: center; border-left: 0.3mm solid #000; padding-left: 1.5mm; }
      .von b { font-size: ${(vg + 0.5).toFixed(1)}pt; }
      .an { flex: 1; min-width: 0; display: flex; flex-direction: column; justify-content: center; padding-left: 5mm; }
      .an .z { font-size: ${gr.toFixed(1)}pt; line-height: 1.25; overflow-wrap: anywhere; }
      .an .z.n, .an .z.ort { font-weight: bold; }
    </style></head><body>${Array.from({ length: Math.max(1, Math.min(200, anzahl | 0 || 1)) }, () => eine).join('')}</body></html>`;
  }

  // Druck über einen unsichtbaren Rahmen, damit die Seite selbst stehen bleibt
  async function drucken({ an, anzahl = 1 }) {
    const z = (an || []).map(s => String(s || '').trim()).filter(Boolean);
    if (!z.length) { alert('Keine Adresse für die Etikette.'); return; }
    const e = await laden();
    document.getElementById('kgeFrame')?.remove();
    const f = document.createElement('iframe'); f.id = 'kgeFrame';
    f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden';
    document.body.appendChild(f);
    const d = f.contentDocument; d.open(); d.write(html(z, e, anzahl)); d.close();
    setTimeout(() => { f.contentWindow.focus(); f.contentWindow.print(); }, 250);
  }

  window.KGE = { verbinden, laden, drucken, zeilen, html, STANDARD };
})();
