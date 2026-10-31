/* kg-stil.js – gemeinsamer Stil für ALLE Knechtgarten-Tools (Vorlage: Offerten-Tool, Tool C).
   Einbinden im <head> direkt nach kg-pw-schutz.js:
     <script src="/kg-stil.js?v=1"></script>

   1) KG.pfade: die Knopf-Icons (Stift, Abfalleimer, Kopieren, Foto, Schloss …) als SVG-Pfade,
      24x24, Linie 1.5px, keine Füllung, Farbe über currentColor. Nie neu zeichnen, immer von hier.
      KG.icon('edit', 14) liefert das fertige <svg>.
   2) Tools mit eigener Icon-Liste übernehmen die Formen:
      - Sprite mit <symbol id="i-…">: wird beim Laden automatisch umgestellt.
      - JS-Objekt mit Pfaden (z. B. ICONS im Wissens-Tool): direkt danach KG.uebernehmen(ICONS).
   3) Runder Icon-Knopf wie .icobtn im Offerten-Tool: Klasse .kg-ibtn (Löschen: .kg-ibtn.danger).
   Überschrift-Icons (z. B. bei aufklappbaren Abschnitten) dürfen eigene sein – hier geht es um Knöpfe. */
(function(){
  const P = {
    edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
    trash: '<path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="M6 7l1 13h10l1-13"/><path d="M10 11v6M14 11v6"/>',
    copy: '<rect x="9" y="9" width="11" height="11" rx="1.5"/><path d="M5 15V5a1.5 1.5 0 0 1 1.5-1.5H15"/>',
    foto: '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="8.5" cy="10.5" r="1.5"/><path d="M21 16l-5-5-9 9"/>',
    lock: '<rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
    unlock: '<rect x="4" y="11" width="16" height="9" rx="2"/><path d="M8 11V7a4 4 0 0 1 7.5-1.8"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    check: '<path d="M5 13l4 4L19 7"/>',
    upload: '<path d="M12 16V4M7 9l5-5 5 5"/><path d="M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3"/>',
    undo: '<path d="M3 12a9 9 0 1 0 3-6.7"/><path d="M3 4v5h5"/>',
    eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/>',
    notiz: '<path d="M4 4h16v16H4z"/><path d="M8 9h8M8 13h6"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    archiv: '<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9M10 13h4"/>',
    senden: '<path d="M4 12h13M12 6l6 6-6 6"/>',
    kalender: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4M7 14h6"/>',
    mikrofon:'<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
    chev: '<path d="M6 9l6 6 6-6"/>',
    fett: '<path d="M7 5h6a3.5 3.5 0 0 1 0 7H7zM7 12h7a3.5 3.5 0 0 1 0 7H7z"/>',
    kursiv: '<path d="M10 5h8M6 19h8M14 5l-4 14"/>',
    aufzaehlung: '<path d="M9 6h11M9 12h11M9 18h11"/><circle cx="4.5" cy="6" r=".8"/><circle cx="4.5" cy="12" r=".8"/><circle cx="4.5" cy="18" r=".8"/>',
    link: '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
    hand: '<path d="M8 13V6a1.5 1.5 0 0 1 3 0v6"/><path d="M11 12.5V4a1.5 1.5 0 0 1 3 0v8.5"/><path d="M14 12.5V6a1.5 1.5 0 0 1 3 0v8"/><path d="M17 10.5a1.5 1.5 0 0 1 3 0V15c0 3.5-2 7-6.5 7h-1.5c-2.3 0-3.8-.7-5.1-2.1l-3-3.2a1.5 1.5 0 0 1 2.1-2.1L8 16"/>',
    gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1Z"/>'
  };
  // andere Namen, unter denen die Tools dieselben Knopf-Icons führen
  const ALIAS = { image: 'foto', bild: 'foto', stift: 'edit', pen: 'edit', loeschen: 'trash', kopieren: 'copy', close: 'x', schliessen: 'x' };
  const name = n => P[n] ? n : ALIAS[n];

  window.KG = {
    pfade: P,
    pfad: n => P[name(n)] || '',
    icon: (n, size = 14, cls = '') => `<svg ${cls ? `class="${cls}" ` : ''}width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${P[name(n)] || ''}</svg>`,
    // JS-Icon-Liste eines Tools (Name -> Pfade) auf die gemeinsamen Formen umstellen
    uebernehmen(liste){ for(const k of Object.keys(liste)) if(name(k)) liste[k] = P[name(k)]; return liste; },
    // Datenbank-Fehler beim Anlegen/Verknüpfen eines Kunden auf Deutsch (sonst e.message unverändert)
    kundeFehlertext(e, vorhandenerName){
      const msg = (e && e.message) || String(e);
      if((e && e.code === '23505') || /kunde_easybill_id_key|duplicate key/i.test(msg)){
        return 'Dieser Kunde existiert bereits und wurde schon erfasst' + (vorhandenerName ? ': «' + vorhandenerName + '»' : '') + '. Bitte in der Kundenliste suchen und diesen Kunden verwenden.';
      }
      return msg;
    }
  };

  // Sprites <symbol id="i-…"> der Tools auf die gemeinsamen Formen umstellen
  function symbole(){
    document.querySelectorAll('symbol[id^="i-"]').forEach(s => { const n = name(s.id.slice(2)); if(n) s.innerHTML = P[n]; });
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', symbole); else symbole();

  // runder Icon-Knopf wie .icobtn im Offerten-Tool
  const css = `.kg-ibtn{width:24px;height:24px;border-radius:50%;border:1px solid var(--line,#E1E5E9);background:#fff;color:var(--muted,#8B9097);
  cursor:pointer;padding:0;flex-shrink:0;display:inline-flex;align-items:center;justify-content:center;box-sizing:border-box;}
.kg-ibtn svg{width:14px;height:14px;}
.kg-ibtn:hover{border-color:var(--primary,#323E4E);color:var(--primary,#323E4E);background:var(--soft,#EEF3F7);}
.kg-ibtn.danger:hover{border-color:var(--danger,#B4655F);color:var(--danger,#B4655F);background:#FBEFEC;}
.kg-ibtn[disabled]{opacity:.35;cursor:default;}`;
  const st = document.createElement('style'); st.id = 'kg-stil'; st.textContent = css;
  (document.head || document.documentElement).appendChild(st);
})();
