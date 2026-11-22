// ============================================================================
// kg-etikette.js – Adressetiketten drucken (gemeinsam für alle Tools)
//
//   KGE.drucken({ an: ['Name', 'Zusatz', 'Strasse', 'PLZ Ort'] })            → Druckdialog
//   KGE.fragen({ titel, an, text })                                         → kleines Fenster «… drucken?»
//   KGE.zeilen(adresse)  macht aus { firma, name, vorname, nachname, zusatz1, zusatz2, strasse, plz, ort, land } die Zeilen
//
// Format 102 × 152 mm (Brother QL, Rolle DK-11241) – auch das Format der späteren Post-Paketetiketten (A6).
// Auf einem normalen Drucker kommt die Etikette in Originalgrösse oben links aufs A4-Blatt (zum Testen).
// Absender klein oben, Empfänger gross. Der Browser zeigt immer den Druckdialog; Chrome merkt sich den
// zuletzt gewählten Drucker, mit dem Brother als Ziel reicht danach Enter.
// ============================================================================
(function () {
  const ABSENDER = ['Knecht AG Naturnahe Gärten', 'Badhaus 42', '3615 Heimenschwand'];
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

  function zeilen(a = {}) {
    const person = [a.vorname, a.nachname].filter(Boolean).join(' ');
    const z = [a.firma || '', a.firma ? person : (person || a.name || ''), a.zusatz1, a.zusatz2, a.strasse, [a.plz, a.ort].filter(Boolean).join(' ')];
    if (a.land && !/^(ch|schweiz|switzerland|suisse|svizzera)$/i.test(String(a.land).trim())) z.push(String(a.land).toUpperCase());
    return z.map(s => String(s || '').trim()).filter(Boolean).filter((s, i, l) => l.indexOf(s) === i);
  }

  function html(an) {
    return `<!DOCTYPE html><html lang="de"><head><meta charset="UTF-8"><title>Etikette</title><style>
      @page { size: 102mm 152mm; margin: 0; }
      * { box-sizing: border-box; }
      html, body { margin: 0; padding: 0; }
      body { font-family: Arial, Helvetica, sans-serif; color: #000; }
      .et { width: 102mm; height: 152mm; padding: 7mm 7mm 6mm; display: flex; flex-direction: column; overflow: hidden; page-break-after: always; }
      .von { font-size: 8.5pt; line-height: 1.3; padding-bottom: 2.5mm; border-bottom: 0.4mm solid #000; }
      .von b { font-size: 9pt; }
      .an { flex: 1; display: flex; flex-direction: column; justify-content: center; padding: 0 2mm 10mm; }
      .an .z { font-size: 15pt; line-height: 1.3; word-break: break-word; }
      .an .z.n { font-weight: bold; }
      .an .z.ort { font-weight: bold; font-size: 16pt; margin-top: 1mm; }
    </style></head><body><div class="et">
      <div class="von"><b>${esc(ABSENDER[0])}</b><br>${ABSENDER.slice(1).map(esc).join(', ')}</div>
      <div class="an">${an.map((s, i) => `<div class="z${i === 0 ? ' n' : ''}${i === an.length - 1 && /^\d{4,5}\s/.test(s) ? ' ort' : ''}">${esc(s)}</div>`).join('')}</div>
    </div></body></html>`;
  }

  // Druck über einen unsichtbaren Rahmen, damit die Seite selbst stehen bleibt
  function drucken({ an }) {
    const z = (an || []).map(s => String(s || '').trim()).filter(Boolean);
    if (!z.length) { alert('Keine Adresse für die Etikette.'); return; }
    document.getElementById('kgeFrame')?.remove();
    const f = document.createElement('iframe'); f.id = 'kgeFrame';
    f.style.cssText = 'position:fixed;right:0;bottom:0;width:0;height:0;border:0;visibility:hidden';
    document.body.appendChild(f);
    const d = f.contentDocument; d.open(); d.write(html(z)); d.close();
    setTimeout(() => { f.contentWindow.focus(); f.contentWindow.print(); }, 250);
  }

  // Kleines Fenster «Etikette drucken?» – Knopf «Drucken» ist vorgewählt (Enter genügt)
  function fragen({ titel = 'Adressetikette drucken?', an = [], text = '' }) {
    document.getElementById('kgeFrage')?.remove();
    const w = document.createElement('div'); w.id = 'kgeFrage';
    w.style.cssText = 'position:fixed;inset:0;background:rgba(35,43,53,.4);z-index:200;display:flex;align-items:center;justify-content:center;padding:16px;font-family:-apple-system,"Segoe UI",Arial,sans-serif';
    w.innerHTML = `<div role="dialog" aria-label="${esc(titel)}" style="background:#fff;border-radius:12px;width:min(380px,100%);box-shadow:0 18px 50px rgba(20,28,38,.35);padding:18px 18px 14px;color:#323E4E">
      <div style="font-weight:700;font-size:16px;margin-bottom:6px">${esc(titel)}</div>
      ${text ? `<div style="font-size:12.5px;color:#6B7079;margin-bottom:10px">${esc(text)}</div>` : ''}
      <div style="font-size:13.5px;line-height:1.45;background:#F5F7F9;border-radius:8px;padding:10px 12px;margin-bottom:14px">${an.map((s, i) => i === 0 ? `<b>${esc(s)}</b>` : esc(s)).join('<br>')}</div>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button type="button" data-kge="nein" style="all:unset;cursor:pointer;height:34px;padding:0 14px;border-radius:8px;border:1px solid #D5DBE1;font-weight:600;font-size:13px">Nicht jetzt</button>
        <button type="button" data-kge="ja" style="all:unset;cursor:pointer;height:34px;padding:0 16px;border-radius:8px;background:#323E4E;color:#fff;font-weight:600;font-size:13px">Etikette drucken</button></div></div>`;
    document.body.appendChild(w);
    const zu = () => { w.remove(); removeEventListener('keydown', taste, true); };
    const taste = e => { if (e.key === 'Escape') { e.preventDefault(); zu(); } else if (e.key === 'Enter') { e.preventDefault(); zu(); drucken({ an }); } };
    addEventListener('keydown', taste, true);
    w.addEventListener('click', e => { const b = e.target.closest('[data-kge]'); if (e.target === w || b?.dataset.kge === 'nein') zu(); else if (b?.dataset.kge === 'ja') { zu(); drucken({ an }); } });
    w.querySelector('[data-kge="ja"]').focus();
  }

  window.KGE = { drucken, fragen, zeilen, ABSENDER };
})();
