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
    griff: '<circle cx="9" cy="6" r="1"/><circle cx="15" cy="6" r="1"/><circle cx="9" cy="12" r="1"/><circle cx="15" cy="12" r="1"/><circle cx="9" cy="18" r="1"/><circle cx="15" cy="18" r="1"/>',
    archiv:'<rect x="3" y="4" width="18" height="5" rx="1"/><path d="M5 9v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V9M10 13h4"/>',
    drucken:'<path d="M7 9V3h10v6"/><rect x="3" y="9" width="18" height="8" rx="2"/><path d="M7 14h10v7H7z"/>',
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

  /* ---------------------------------------------------------------------------
     Farbkonzept (abgenommen 2026-11-01, Mockup «Gesamt-Tool»)
     KG.grund:   Grundfarben für Aufbau, Menü, Knöpfe – überall gleich.
     KG.palette: erweiterte Palette, 10 Familien × 5 Stufen (Index 0 = Stufe 1 dunkel … 4 = Stufe 5 hell)
                 für Tool-Icons (Stufe 2), Pendenzen-Listen, Personen im Einsatzplaner usw.
     KG.planerTeams: Farben pro Team im Einsatzplaner, in Vergabe-Reihenfolge (Variante C).
     KG.textAuf(hex): weiss oder dunkel – was auf dieser Farbe besser lesbar ist.
     --------------------------------------------------------------------------- */
  const PAL = {
    gruen:   ['#2E5A2F', '#3F7D3F', '#62A055', '#9CC98A', '#D3EBC7'],
    oliv:    ['#5A6118', '#7C8726', '#A3AE3A', '#C9D35E', '#E8EDB0'],
    gold:    ['#8A6410', '#B88A12', '#E0AE24', '#F2CF5E', '#FAEBB0'],
    orange:  ['#8A3F12', '#C05A1C', '#E57E34', '#F2A66B', '#F9D3B2'],
    beere:   ['#7A2638', '#A63A52', '#CC5E76', '#E596A6', '#F4CDD5'],
    violett: ['#3E2A6B', '#5C3F94', '#8063BD', '#AD95DD', '#DCD0F3'],
    blau:    ['#1F3F6E', '#2F5C9A', '#4F80C2', '#8CB0DE', '#CCDDF2'],
    petrol:  ['#1E5552', '#2A7570', '#3F9890', '#7FC1B9', '#C4E4DF'],
    erde:    ['#4E3524', '#6E4C35', '#94704F', '#BE9E80', '#E3D2C0'],
    grau:    ['#323E4E', '#4C5C70', '#6E7F93', '#A3B0BE', '#DCE2E8']
  };
  KG.palette = PAL;
  KG.grund = { primary: '#323E4E', primaryL: '#4C5C70', ink: '#232B35', muted: '#8B9097', mutedText: '#6B7079',
    line: '#E1E5E9', bg: '#F5F7F9', accentBlue: '#D6E7F4', accentLime: '#D1DB5F', danger: '#B4655F' };
  KG.planerTeams = {
    projektleiter: [PAL.gruen[1], PAL.gruen[2], PAL.gruen[3], PAL.gruen[4]],
    selber:        [PAL.oliv[2], PAL.oliv[3]],
    gartenpflege:  [PAL.gold[2], PAL.orange[2], PAL.gold[3], PAL.orange[3], PAL.gold[4], PAL.orange[4]],
    gartenbau:     [PAL.violett[1], PAL.petrol[2], PAL.blau[1], PAL.violett[3], PAL.blau[2], PAL.violett[2], PAL.violett[4]],
    pool:          [PAL.blau[4], PAL.petrol[4]]
  };
  const lum = hex => { const n = parseInt(String(hex).replace('#', ''), 16) || 0;
    const f = c => { c /= 255; return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(n >> 16) + 0.7152 * f((n >> 8) & 255) + 0.0722 * f(n & 255); };
  KG.textAuf = hex => { const L = lum(hex); return 1.05 / (L + 0.05) >= (L + 0.05) / (lum('#232B35') + 0.05) ? '#FFFFFF' : '#232B35'; };

  /* ---------------------------------------------------------------------------
     Tool-Icons (Haupttools): Linien-Icon auf farbiger Kachel, Farbe = Stufe 2.
     KG.toolIcon('pend', 26) liefert die fertige Kachel.
     --------------------------------------------------------------------------- */
  const TI = {
    home: '<path d="M3 11l9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M10 20v-6h4v6"/>',
    offerten: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5"/><path d="M9 13h6M9 17h4"/>',
    artikel: '<path d="M4 5v14M7.5 5v14M10 5v14M13.5 5v14M17 5v14M20 5v14"/>',
    kunden: '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.5 2.9-6 6.5-6s6.5 2.5 6.5 6"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7"/><path d="M18 14.3c2 .8 3.5 2.9 3.5 5.7"/>',
    pend: '<path d="M4 6l1.5 1.5L8 5"/><path d="M11 6h9"/><path d="M4 12l1.5 1.5L8 11"/><path d="M11 12h9"/><circle cx="6" cy="18" r="1.5"/><path d="M11 18h9"/>',
    plan: '<path d="M3 4v16h18"/><rect x="6" y="6" width="8" height="3" rx="1"/><rect x="10" y="11" width="9" height="3" rx="1"/><rect x="7" y="15.5" width="6" height="2.5" rx="1"/>',
    pflege: '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z"/><path d="M5 19l8-8"/>',
    wissen: '<path d="M3 5.5C5.5 4.5 9 4.5 12 6.5c3-2 6.5-2 9-1v13c-2.5-1-6-1-9 1-3-2-6.5-2-9-1z"/><path d="M12 6.5v13"/>',
    rechner: '<rect x="5" y="3" width="14" height="18" rx="2"/><rect x="8" y="6" width="8" height="3" rx=".5"/><path d="M8 13h1M11.5 13h1M15 13h1M8 17h1M11.5 17h1M15 17h1"/>',
    verw: P.gear
  };
  // Haupttools: Schlüssel, Name, Einstiegsseite, Icon, Farbe, Modul in modul_sichtbarkeit, zugehörige Seiten
  const TOOLS = [
    { k: 'home', n: 'Startseite', url: 'index.html', farbe: PAL.oliv[1], seiten: ['index'] },
    { k: 'offerten', n: 'Offertentool', url: 'tool-start-live-v1.html', farbe: PAL.blau[1], modul: 'offertentool',
      seiten: ['tool-start-live-v1', 'tool-a-live-v1', 'tool-a2-allgemein-live-v1', 'tool-a3-artikel-live-v1', 'tool-b-live-v1', 'einstellungen-live-v1'] },
    { k: 'artikel', n: 'Artikelstamm', url: 'tool-c-live-v1.html', farbe: PAL.blau[1], modul: 'offertentool', seiten: ['tool-c-live-v1', 'lieferant-abgleich-live-v1'] },
    { k: 'kunden', n: 'Kunden', url: 'tool-d-kunden-live-v1.html', farbe: PAL.gold[0], modul: 'offertentool', seiten: ['tool-d-kunden-live-v1'] },
    { k: 'pend', n: 'Pendenzen', url: 'pendenzen-live-v1.html', farbe: PAL.orange[1], modul: 'pendenzen', seiten: ['pendenzen-live-v1'] },
    { k: 'plan', n: 'Einsatzplaner', url: 'einsatzplaner-live-v1.html', farbe: PAL.petrol[1], modul: 'einsatzplaner', seiten: ['einsatzplaner-live-v1'] },
    { k: 'pflege', n: 'Pflege & Service', url: 'pflege-kunden-live-v1.html', farbe: PAL.gruen[1], modul: 'pflegetool',
      seiten: ['pflege-kunden-live-v1', 'pflege-jahresplan-live-v1', 'pflege-kategorien-live-v1'] },
    { k: 'wissen', n: 'Nachschlagewerk', url: 'wissen-live-v1.html', farbe: PAL.violett[1], modul: 'wissen', seiten: ['wissen-live-v1'] },
    { k: 'verw', n: 'Verwaltung', url: 'verwaltung-live-v1.html', farbe: '#FFFFFF', admin: true,
      seiten: ['verwaltung-live-v1', 'tools-live-v1', 'mailassistent-verwaltung-live-v1', 'dokumentensuche-verwaltung-live-v1'] }
  ];
  KG.tools = TOOLS;
  KG.toolIcons = TI;
  KG.toolIcon = (k, size = 26) => {
    const t = TOOLS.find(x => x.k === k) || {}; const hell = t.farbe === '#FFFFFF';
    const g = Math.round(size * 0.74);
    return `<span class="kg-ti" style="width:${size}px;height:${size}px;border-radius:${Math.round(size * 0.26)}px;background:${t.farbe || PAL.grau[1]};color:${hell ? '#323E4E' : '#FFFFFF'}">`
      + `<svg width="${g}" height="${g}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">${TI[k] || ''}</svg></span>`;
  };

  /* ---------------------------------------------------------------------------
     Gemeinsame Leiste: in jedem <header class="app"> wird «Zurück» + Tool-Titel
     durch den Tool-Umschalter ersetzt (Icon + Name + Pfeil, Klick = Menü aller Tools).
     Rechte Seite (Reiter, Benutzer, Abmelden) bleibt wie im jeweiligen Tool.
     Seiten ohne Eintrag in KG.tools (z. B. Datenschutz) bleiben unverändert.
     --------------------------------------------------------------------------- */
  const seite = (location.pathname.split('/').pop() || 'index.html').replace(/\.html?$/, '') || 'index';
  const aktuell = TOOLS.find(t => t.seiten.includes(seite));
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);

  const cssLeiste = `.kg-ti{display:inline-flex;align-items:center;justify-content:center;flex-shrink:0;box-sizing:border-box;}
header.app .wrap{min-height:46px;}
.kg-tw{display:inline-flex;align-items:center;gap:8px;height:34px;padding:0 10px 0 4px;border:0;border-radius:9px;background:rgba(255,255,255,.08);
  color:#fff;font:inherit;font-size:14px;font-weight:600;cursor:pointer;flex-shrink:0;white-space:nowrap;}
.kg-tw:hover,.kg-tw[aria-expanded="true"]{background:rgba(255,255,255,.16);}
.kg-tw .kg-chev{width:14px;height:14px;opacity:.8;transition:transform .15s;}
.kg-tw[aria-expanded="true"] .kg-chev{transform:rotate(180deg);}
.kg-twmenu{position:fixed;z-index:9999;width:560px;max-width:calc(100vw - 24px);box-sizing:border-box;background:#fff;color:#232B35;
  border:1px solid #E1E5E9;border-radius:12px;box-shadow:0 16px 40px rgba(35,43,53,.18);padding:14px;font-size:13px;}
.kg-twmenu .kg-h{font-size:11px;font-weight:600;letter-spacing:.06em;color:#6B7079;text-transform:uppercase;padding:0 6px 8px;}
.kg-twmenu .kg-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:4px;}
.kg-twmenu .kg-it{display:flex;align-items:center;gap:10px;padding:8px;border-radius:8px;text-decoration:none;color:#232B35;font-weight:600;}
.kg-twmenu .kg-it:hover{background:#F5F7F9;}
.kg-twmenu .kg-it.on{background:#EEF3F7;}
.kg-twmenu .kg-it .kg-ti[style*="#FFFFFF"]{border:1px solid #E1E5E9;}
.kg-twmenu .kg-sep{height:1px;background:#E1E5E9;margin:12px 0;}
.kg-twmenu .kg-ext{display:flex;flex-wrap:wrap;gap:6px;padding:0 4px;}
.kg-twmenu .kg-ext a{display:inline-flex;align-items:center;gap:5px;height:26px;padding:0 10px;border:1px solid #E1E5E9;border-radius:13px;font-size:12px;color:#232B35;text-decoration:none;}
.kg-twmenu .kg-ext a:hover{border-color:#323E4E;}
.kg-twmenu .kg-ext svg{width:12px;height:12px;color:#6B7079;}
@media (max-width:600px){.kg-twmenu .kg-grid{grid-template-columns:repeat(2,minmax(0,1fr));}}
/* Einheitliche Leiste: [Umschalter][Reiter …][Tool-Icons] … [Hilfe][Person] */
header.app.kg-leiste .wrap{max-width:none!important;padding:0 16px!important;margin:0!important;gap:14px!important;flex-wrap:nowrap!important;}
header.app.kg-leiste .kg-reiter{display:flex!important;align-items:stretch;gap:2px;flex:1 1 auto;min-width:0;margin:0!important;background:transparent!important;border:0!important;overflow-x:auto;scrollbar-width:none;}
header.app.kg-leiste .kg-reiter.hidden{visibility:hidden;}
header.app.kg-leiste .kg-reiter::-webkit-scrollbar,header.app.kg-leiste .kg-reiter .wrap::-webkit-scrollbar{display:none;}
header.app.kg-leiste .kg-reiter .wrap{display:flex!important;align-items:stretch;gap:2px;flex:1;padding:0!important;min-height:0!important;max-width:none!important;margin:0!important;
  background:transparent!important;overflow:visible!important;}
header.app.kg-leiste .userbar .kg-rund{width:32px!important;height:32px!important;padding:0!important;border-radius:50%!important;border:1px solid rgba(255,255,255,.22)!important;
  background:transparent!important;color:#C9D1DB!important;font-size:12px!important;font-weight:700!important;opacity:1!important;}
header.app.kg-leiste .userbar .kg-rund.kg-person{background:#4C5C70!important;color:#fff!important;}
header.app.kg-leiste .userbar .kg-rund:hover,header.app.kg-leiste .userbar .kg-rund[aria-expanded="true"]{border-color:rgba(255,255,255,.55)!important;color:#fff!important;}
header.app.kg-leiste .kg-reiter a:not(.navic):not(.icobtn),header.app.kg-leiste .kg-reiter > .wrap > button:not(.navic){all:unset;box-sizing:border-box;display:flex;align-items:center;gap:6px;
  height:46px;padding:0 12px;border-bottom:2px solid transparent;border-top:2px solid transparent;color:#C9D1DB;font-size:13px;font-weight:600;white-space:nowrap;cursor:pointer;}
header.app.kg-leiste .kg-reiter a:not(.navic):not(.icobtn):hover,header.app.kg-leiste .kg-reiter > .wrap > button:not(.navic):hover{color:#fff;}
header.app.kg-leiste .kg-reiter a.on:not(.navic),header.app.kg-leiste .kg-reiter > .wrap > button.on:not(.navic){color:#fff;border-bottom-color:#D1DB5F;}
header.app.kg-leiste .kg-reiter a:not(.navic) svg,header.app.kg-leiste .kg-reiter > .wrap > button:not(.navic):not([data-act="handy"]) > svg{display:none;}
header.app.kg-leiste .kg-reiter .hidden{display:none!important;}
header.app.kg-leiste .kg-reiter .navsp,header.app.kg-leiste .kg-reiter .neu{flex:1;margin-left:auto;}
header.app.kg-leiste .kg-reiter .navic,header.app.kg-leiste .kg-reiter .icobtn:not(#supportChatBtn){all:unset;box-sizing:border-box;cursor:pointer;display:flex;align-items:center;justify-content:center;
  width:32px;height:46px;color:#C9D1DB;}
header.app.kg-leiste .kg-reiter .navic:hover{color:#fff;}
header.app.kg-leiste .kg-reiter .navic.on{color:#fff;box-shadow:inset 0 -2px 0 #D1DB5F;}
header.app.kg-leiste .kg-reiter .navmodus{margin-left:auto;display:flex;align-items:center;background:rgba(255,255,255,.08);border-radius:8px;padding:2px;}
header.app.kg-leiste .kg-reiter .navmodus button{all:unset;cursor:pointer;display:flex;align-items:center;gap:5px;height:28px;padding:0 10px;border-radius:6px;color:#C9D1DB;font-size:12px;font-weight:600;}
header.app.kg-leiste .kg-reiter .navmodus button.on{background:#fff;color:#323E4E;}
header.app.kg-leiste .kg-reiter .navmodus svg{width:14px;height:14px;}
header.app.kg-leiste #supportChatBtn,header.app.kg-leiste #userbarText,header.app.kg-leiste #logoutBtn,header.app.kg-leiste #hknoepfe [data-seto]{display:none!important;}
header.app.kg-leiste .userbar{display:flex;align-items:center;gap:8px;margin-left:auto!important;flex-shrink:0;}
header.app.kg-leiste .userbar.hidden{display:none!important;}
.kg-rund{all:unset;box-sizing:border-box;width:32px;height:32px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;cursor:pointer;flex-shrink:0;
  color:#C9D1DB;border:1px solid rgba(255,255,255,.22);font-size:12px;font-weight:700;}
.kg-rund:hover,.kg-rund[aria-expanded="true"]{color:#fff;border-color:rgba(255,255,255,.55);}
.kg-rund svg{width:16px;height:16px;}
.kg-rund.kg-person{background:#4C5C70;color:#fff;}
.kg-pmenu{width:260px;padding:8px;}
.kg-pmenu .kg-pkopf{padding:8px 10px 10px;border-bottom:1px solid #E1E5E9;margin-bottom:6px;}
.kg-pmenu .kg-pkopf b{display:block;font-size:13px;color:#232B35;}
.kg-pmenu .kg-pkopf span{font-size:12px;color:#6B7079;}
.kg-pmenu button,.kg-pmenu a{all:unset;box-sizing:border-box;width:100%;display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:8px;cursor:pointer;font-size:13px;color:#232B35;}
.kg-pmenu button:hover,.kg-pmenu a:hover{background:#F5F7F9;}
.kg-pmenu svg{width:16px;height:16px;color:#6B7079;flex-shrink:0;}
.kg-pmenu .kg-sep{margin:6px 0;}`;
  const st2 = document.createElement('style'); st2.id = 'kg-leiste'; st2.textContent = cssLeiste;
  (document.head || document.documentElement).appendChild(st2);

  const EXT = '<path d="M14 4h6v6"/><path d="M20 4l-9 9"/><path d="M18 14v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V7a1 1 0 0 1 1-1h5"/>';
  let sicht = null; // { rolle, module: Map modul_key -> sichtbar, extern: [] } – erst beim ersten Öffnen geladen

  async function ladeSichtbarkeit(){
    if(sicht) return sicht;
    sicht = { rolle: null, module: null, extern: [] };
    try {
      // eigener Client (gleiche Anmeldung wie die Seite), weil nicht jede Seite sb global anlegt
      if(!window.supabase || !window.supabase.createClient) return sicht;
      KG._sb = KG._sb || window.supabase.createClient('https://oalapdxinqlnzwxhyuzy.supabase.co', 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P');
      const client = KG._sb;
      const { data: { session } } = await client.auth.getSession();
      if(!session) return sicht;
      const [{ data: ben }, { data: mods }] = await Promise.all([
        client.from('benutzer').select('rolle').eq('id', session.user.id).maybeSingle(),
        client.from('modul_sichtbarkeit').select('modul_key,name,kurzname,url,ist_extern,fuer_buero_team,fuer_mitarbeitende,fuer_service_team')
      ]);
      sicht.rolle = ben && ben.rolle;
      const spalte = { buero_team: 'fuer_buero_team', mitarbeitende: 'fuer_mitarbeitende', service_team: 'fuer_service_team' }[sicht.rolle];
      const darf = m => sicht.rolle === 'admin' || (spalte && m[spalte]);
      sicht.module = new Map((mods || []).map(m => [m.modul_key, darf(m)]));
      sicht.extern = (mods || []).filter(m => m.ist_extern && m.url && darf(m)).sort((a, b) => (a.kurzname || a.name).localeCompare(b.kurzname || b.name, 'de'));
    } catch(e){ /* ohne Daten: alle Tools zeigen, die Seiten prüfen den Zugriff selbst */ }
    return sicht;
  }

  function sichtbar(t, s){
    if(t.k === 'home' || t.k === aktuell.k) return true;
    if(t.admin) return s.rolle === 'admin' || (s.module && s.module.get('tools'));
    if(!s.module || !t.modul) return true;
    return s.module.get(t.modul) !== false;
  }

  function menuHtml(s){
    const verwUrl = s.rolle && s.rolle !== 'admin' ? 'tools-live-v1.html' : 'verwaltung-live-v1.html';
    const items = TOOLS.filter(t => sichtbar(t, s)).map(t =>
      `<a class="kg-it${t.k === aktuell.k ? ' on' : ''}" href="${t.k === 'verw' ? verwUrl : t.url}">${KG.toolIcon(t.k, 32)}<span>${esc(t.n)}</span></a>`).join('');
    const ext = s.extern.length ? `<div class="kg-sep"></div><div class="kg-h">Externe Links</div><div class="kg-ext">${s.extern.map(m =>
      `<a href="${esc(m.url)}" target="_blank" rel="noopener"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${EXT}</svg>${esc(m.kurzname || m.name)}</a>`).join('')}</div>` : '';
    return `<div class="kg-h">Tools</div><div class="kg-grid">${items}</div>${ext}`;
  }

  function leiste(){
    const head = document.querySelector('header.app');
    if(!head || !aktuell || head.querySelector('.kg-tw')) return;
    const wrap = head.querySelector('.wrap') || head;
    const back = wrap.querySelector('.backlink'), brand = wrap.querySelector('.brand');
    const btn = document.createElement('button');
    btn.type = 'button'; btn.className = 'kg-tw'; btn.setAttribute('aria-haspopup', 'true'); btn.setAttribute('aria-expanded', 'false');
    btn.title = 'Tool wechseln';
    btn.innerHTML = `${KG.toolIcon(aktuell.k, 28)}<span>${esc(aktuell.n)}</span><svg class="kg-chev" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${P.chev}</svg>`;
    if(back) back.replaceWith(btn); else wrap.insertBefore(btn, wrap.firstChild);
    if(brand) brand.style.display = 'none';

    popup(btn, 'kg-twmenu', 'links', async setze => { setze(menuHtml({ rolle: null, module: null, extern: [] })); setze(menuHtml(await ladeSichtbarkeit())); });
    vereinheitlichen(head, wrap, btn);
  }

  // Aufklappmenü unter einem Knopf (links- oder rechtsbündig), schliesst bei Klick daneben / Esc
  function popup(btn, cls, seite, fuellen){
    let menu = null;
    const zu = () => { if(menu){ menu.remove(); menu = null; } btn.setAttribute('aria-expanded', 'false'); };
    const auf = () => {
      menu = document.createElement('div'); menu.className = 'kg-twmenu ' + cls; menu.setAttribute('role', 'menu');
      const r = btn.getBoundingClientRect();
      menu.style.top = (r.bottom + 6) + 'px';
      if(seite === 'rechts') menu.style.right = Math.max(12, window.innerWidth - r.right) + 'px'; else menu.style.left = Math.max(12, r.left) + 'px';
      document.body.appendChild(menu); btn.setAttribute('aria-expanded', 'true');
      fuellen(html => { if(menu) menu.innerHTML = html; }, zu);
    };
    btn.setAttribute('aria-haspopup', 'true'); btn.setAttribute('aria-expanded', 'false');
    btn.addEventListener('click', e => { e.stopPropagation(); menu ? zu() : auf(); });
    document.addEventListener('click', e => { if(menu && !menu.contains(e.target)) zu(); });
    document.addEventListener('keydown', e => { if(e.key === 'Escape' && menu){ zu(); btn.focus(); } });
    window.addEventListener('resize', zu);
  }

  /* Einheitliche Leiste:
     - Reiter direkt nach dem Umschalter, links: Offertentool-Reiter aus <nav> im Kopf, sonst die weisse
       <nav class="subnav"> wird als Ganzes in die Leiste verschoben (Element bleibt erhalten, damit die
       Tool-Skripte es weiter über #subnav finden). Tool-Icons (.navic) stehen rechts in den Reitern.
     - Offertentool: Zahnrad wird zum Reiter «Vorlagen & Berechnung».
     - Rechts nur noch: Hilfe (wenn das Tool einen Support-Chat hat) und das Personen-Menü
       (Meine Einstellungen, Verwaltung, Abmelden). Die alten Knöpfe bleiben versteckt im DOM und werden angeklickt. */
  const SVG = p => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
  const I_HILFE = '<circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 0 1 4.9.7c0 1.7-2.4 2.1-2.4 3.6"/><path d="M12 17h.01"/>';
  const I_AUS = '<path d="M15 4h4a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-4"/><path d="M10 16l-4-4 4-4"/><path d="M6 12h10"/>';
  const I_PERSON = '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/>';

  function vereinheitlichen(head, wrap, btn){
    head.classList.add('kg-leiste');
    const kopfNav = wrap.querySelector(':scope > nav:not(.subnav)');
    const sub = document.querySelector('nav.subnav');
    let reiter = null;
    if(kopfNav){
      reiter = kopfNav;
      const gear = kopfNav.querySelector('a.gear');
      const tabs = [...kopfNav.querySelectorAll(':scope > a:not(.icobtn):not(.gear)')];
      if(gear){ gear.textContent = 'Vorlagen & Berechnung'; gear.removeAttribute('title'); if(tabs.length) tabs[tabs.length - 1].after(gear); }
    } else if(sub && !head.contains(sub)){
      reiter = sub;
    }
    if(reiter){ reiter.classList.add('kg-reiter'); btn.after(reiter); }

    const ub = document.getElementById('userbar');
    if(!ub) return;
    wrap.appendChild(ub);
    const hilfeOrig = document.getElementById('supportChatBtn');
    if(hilfeOrig){
      const h = document.createElement('button'); h.type = 'button'; h.className = 'kg-rund'; h.title = 'Hilfe & Support'; h.setAttribute('aria-label', 'Hilfe & Support');
      h.innerHTML = SVG(I_HILFE); h.addEventListener('click', e => { e.stopPropagation(); hilfeOrig.click(); });
      ub.appendChild(h);
    }
    const p = document.createElement('button'); p.type = 'button'; p.className = 'kg-rund kg-person'; p.title = 'Mein Konto'; p.setAttribute('aria-label', 'Mein Konto');
    const txt = document.getElementById('userbarText');
    const initialen = () => {
      const t = (txt && txt.textContent || '').trim(); const n = t.replace(/\s*\(.*$/, '').split('@')[0];
      p.innerHTML = n ? esc(n.split(/[\s.]+/).filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join('')) : SVG(I_PERSON);
    };
    initialen();
    if(txt) new MutationObserver(initialen).observe(txt, { childList: true, characterData: true, subtree: true });
    ub.appendChild(p);

    popup(p, 'kg-pmenu', 'rechts', async (setze, zu) => {
      const t = (txt && txt.textContent || '').trim();
      const name = t.replace(/\s*\(.*$/, '') || 'Angemeldet', rolle = (t.match(/\(([^)]*)\)/) || [])[1] || '';
      const eigene = document.querySelector('#hknoepfe [data-seto]');
      const bau = s => {
        const verw = s.rolle === 'admin' ? 'verwaltung-live-v1.html' : (s.module && s.module.get('tools') ? 'tools-live-v1.html' : null);
        return `<div class="kg-pkopf"><b>${esc(name)}</b>${rolle ? `<span>${esc(rolle)}</span>` : ''}</div>`
          + (eigene ? `<button type="button" data-k="eigene">${SVG(P.gear)}Meine Einstellungen · ${esc(aktuell.n)}</button>` : '')
          + (verw && aktuell.k !== 'verw' ? `<a href="${verw}">${SVG(P.gear)}Verwaltung</a>` : '')
          + `<div class="kg-sep"></div><button type="button" data-k="aus">${SVG(I_AUS)}Abmelden</button>`;
      };
      const binden = () => {
        const m = document.querySelector('.kg-pmenu'); if(!m) return;
        const e = m.querySelector('[data-k="eigene"]'); if(e) e.addEventListener('click', () => { zu(); const x = document.querySelector('#hknoepfe [data-seto]'); if(x) x.click(); });
        const a = m.querySelector('[data-k="aus"]'); if(a) a.addEventListener('click', () => { zu(); const x = document.getElementById('logoutBtn'); if(x) x.click(); });
      };
      setze(bau({ rolle: null, module: null })); binden();
      const s = await ladeSichtbarkeit(); setze(bau(s)); binden();
    });
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', leiste); else leiste();
})();
