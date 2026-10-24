// ============================================================================
// Kuerzel wie Text Blaze: Tippt man in einem Eingabefeld, Textfeld oder
// contenteditable (z.B. Gmail-Mailfenster) ein Kuerzel wie "/mwst" und
// danach Leerschlag oder Tab, wird es durch den Wert der Kurzinfo ersetzt.
// Leerschlag bleibt danach stehen, Tab nicht (Tab springt dann auch nicht ins
// naechste Feld).
//
// Die Liste [{ kuerzel, wert }] kommt aus chrome.storage.local ("kuerzelListe",
// geladen von background.js). Hier wird nur gelesen, nie etwas verschickt.
// Passwortfelder werden absichtlich nie angefasst.
// ============================================================================

(() => {
  let liste = [];

  chrome.storage.local.get('kuerzelListe').then(({ kuerzelListe }) => { liste = kuerzelListe || []; });
  chrome.storage.onChanged.addListener((aenderung, bereich) => {
    if (bereich === 'local' && aenderung.kuerzelListe) liste = aenderung.kuerzelListe.newValue || [];
  });

  // Laengstes passendes Kuerzel am Ende des Textes vor dem Cursor. Davor muss
  // der Textanfang oder ein Leerzeichen/Zeilenumbruch/Klammer stehen, damit
  // z.B. "https://x.ch/mwst" nicht ersetzt wird.
  function findeKuerzel(textVorCursor) {
    const klein = textVorCursor.toLowerCase();
    let treffer = null;
    for (const k of liste) {
      const kz = (k.kuerzel || '').toLowerCase();
      if (!kz || !klein.endsWith(kz)) continue;
      const davor = textVorCursor.charAt(textVorCursor.length - kz.length - 1);
      if (davor && !/[\s(«"']/.test(davor)) continue;
      if (!treffer || kz.length > treffer.kuerzel.length) treffer = k;
    }
    return treffer;
  }

  const TEXT_TYPEN = ['text', 'search', 'url', 'tel', ''];

  function ersetzeInFeld(el, nachher) {
    const pos = el.selectionStart;
    if (pos == null || pos !== el.selectionEnd) return false;
    const treffer = findeKuerzel(el.value.slice(0, pos));
    if (!treffer) return false;
    // Einzeilige Felder: Zeilenumbrueche (z.B. Rechnungsadresse) als ", ".
    let wert = String(treffer.wert ?? '');
    if (el.tagName !== 'TEXTAREA') wert = wert.split(/\r?\n/).map((z) => z.trim()).filter(Boolean).join(', ');
    el.setSelectionRange(pos - treffer.kuerzel.length, pos);
    // execCommand haelt Rueckgaengig (Ctrl+Z) intakt und loest die normalen
    // input-Ereignisse aus (wichtig fuer React-/Angular-Seiten wie E-Banking).
    if (!document.execCommand('insertText', false, wert + nachher)) {
      el.setRangeText(wert + nachher, pos - treffer.kuerzel.length, pos, 'end');
      el.dispatchEvent(new Event('input', { bubbles: true }));
    }
    return true;
  }

  function ersetzeInEditierbar(nachher) {
    const sel = window.getSelection();
    if (!sel || !sel.isCollapsed || !sel.anchorNode || sel.anchorNode.nodeType !== Node.TEXT_NODE) return false;
    const knoten = sel.anchorNode;
    const pos = sel.anchorOffset;
    const treffer = findeKuerzel(knoten.data.slice(0, pos));
    if (!treffer) return false;
    const range = document.createRange();
    range.setStart(knoten, pos - treffer.kuerzel.length);
    range.setEnd(knoten, pos);
    sel.removeAllRanges();
    sel.addRange(range);
    const zeilen = String(treffer.wert ?? '').split(/\r?\n/);
    zeilen.forEach((zeile, i) => {
      if (i > 0) document.execCommand('insertLineBreak');
      if (zeile) document.execCommand('insertText', false, zeile);
      else if (i === 0) document.execCommand('delete');
    });
    if (nachher) document.execCommand('insertText', false, nachher);
    return true;
  }

  document.addEventListener('keydown', (e) => {
    if (!liste.length || e.isComposing || e.ctrlKey || e.altKey || e.metaKey) return;
    let nachher;
    if (e.key === ' ') nachher = ' ';
    else if (e.key === 'Tab' && !e.shiftKey) nachher = '';
    else return;

    // composedPath()[0]: echtes Feld auch innerhalb von Shadow-DOM.
    const el = e.composedPath()[0];
    if (!(el instanceof HTMLElement)) return;
    let ersetzt = false;
    if (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && TEXT_TYPEN.includes((el.getAttribute('type') || '').toLowerCase()))) {
      if (el.readOnly || el.disabled) return;
      ersetzt = ersetzeInFeld(el, nachher);
    } else if (el.isContentEditable) {
      ersetzt = ersetzeInEditierbar(nachher);
    }
    if (ersetzt) {
      e.preventDefault();
      e.stopPropagation();
    }
  }, true);
})();
