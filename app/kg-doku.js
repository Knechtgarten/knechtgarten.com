/* kg-doku.js – gemeinsame Teile des Tools «Doku-Tools» (Dokumente aus Vorlagen).
   Einbinden nach supabase-js:  <script src="/kg-doku.js?v=1"></script>
   - KGD.start(fertig): Login, Rechte, Personen laden, danach fertig(main)
   - KGD.TYPEN: Dokumenttypen im Code (Daten-Fenster, Dateiname); Text steht in doku_vorlage.html
   - KGD.FELDER: Platzhalter im Brief (<span data-f="…"> bzw. <div data-f="…"> für Blöcke)
   - KGD.brief(el, html, werte, modus): Brief zeichnen; modus 'fuellen' (Werte markiert), 'druck', 'admin' (Chips)
   - KGD.editor(ed): Vorlagen-Editor (Leiste, Chips verschieben/formatieren), KGD.vorlageLesen(ed)
   - KGD.drucken(blatt), KGD.pdf(blatt, name)
   Neue Felder oder Dokumenttypen kommen nur hier in den Code (Entscheid Nutzer 2026-11-03). */
(function(){
  const $ = id => document.getElementById(id);
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const ic = (n, s = 16) => KG.icon(n, s);
  const lsGet = (k, alt) => { try { const v = localStorage.getItem(k); return v === null ? alt : JSON.parse(v); } catch(e){ return alt; } };
  const lsSet = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch(e){} };

  const ROLLEN = { projektleiter: 'Projektleiter', bauleiter: 'Bauführer', vorarbeiter: 'Vorarbeiter' };
  const MON = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
  const TAGE = ['Sonntag','Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag'];
  const datumLang = v => { if(!v) return '…'; const d = new Date(v + 'T12:00'); return `${TAGE[d.getDay()]}, ${d.getDate()}. ${MON[d.getMonth()]} ${d.getFullYear()}`; };
  const datumKurz = v => { if(!v) return ''; const [j, m, t] = v.slice(0, 10).split('-'); return `${+t}.${+m}.${j}`; };
  const heute = () => { const d = new Date(); return `${String(d.getDate()).padStart(2, '0')}.${String(d.getMonth() + 1).padStart(2, '0')}.${d.getFullYear()}`; };
  const uhr = t => (t || '').replace(':', '.');
  const ortOhnePlz = o => String(o || '').replace(/^\d{4}\s*/, '');
  const adresse = w => [w.strasse, ortOhnePlz(w.ort)].filter(Boolean).join(', ');
  const person = id => (KGD.personen || []).find(p => p.id === id) || null;

  // Felder (Platzhalter im Brief) ---------------------------------------------------------------
  const FELDER = {
    datum:         { chip: 'Datum', wert: w => datumLang(w.datum) },
    zeit:          { chip: 'Zeit', wert: w => w.von && w.bis ? `zwischen ${uhr(w.von)} und ${uhr(w.bis)} Uhr` : w.von ? `ab ${uhr(w.von)} Uhr`
                       : w.bis ? `bis ${uhr(w.bis)} Uhr` : '(die genaue Zeit geben wir kurzfristig bekannt)' },
    kunde_adresse: { chip: 'Kunde · Adresse', wert: w => adresse(w) || '…' },
    kunde_name:    { chip: 'Kunde · Name', wert: w => w.kunde_name || '' },
    pl_name:       { chip: 'Projektleiter · Name', wert: w => (person(w.pl) || {}).name || '…' },
    pl_telefon:    { chip: 'Projektleiter · Handy', wert: w => (person(w.pl) || {}).telefon || '' },
    pl_block:      { chip: 'Kontaktblock Projektleiter', info: 'Name, Rolle, Handy, Mail', block: true, html: w => {
                       const p = person(w.pl); if(!p) return '<div class="kgd-pers w">…</div>';
                       return `<div class="kgd-pers w"><span>${esc(p.name)}</span><span>${esc(ROLLEN[p.rolle] || '')}</span>${p.telefon ? `<span>${esc(p.telefon)}</span>` : ''}${p.mail ? `<span class="kgd-mail">${esc(p.mail)}</span>` : ''}</div>`; } },
    zusatz_block:  { chip: 'Zusatz (optional)', info: 'eigener Satz, z. B. Umleitung', block: true,
                     html: w => w.zusatz ? `<p class="w" style="white-space:pre-line">${esc(w.zusatz)}</p>` : '' },
    va_block:      { chip: 'Kontaktblock Vorarbeiter vor Ort', info: 'nur wenn gewählt', block: true, html: w => {
                       const p = person(w.va); if(!p) return '';
                       return `<div class="kgd-pers w"><span>Vorarbeiter vor Ort:</span><span>${esc(p.name)}</span>${p.telefon ? `<span>${esc(p.telefon)}</span>` : ''}</div>`; } }
  };
  // Dokumenttypen: welche Felder das Daten-Fenster zeigt, Dateiname, Pflichtangaben
  const TYPEN = {
    helikopter: { daten: ['adresse', 'termin', 'pl', 'va'], pflicht: w => !w.datum ? 'Datum fehlt.' : !adresse(w) ? 'Adresse fehlt.' : '',
                  dateiname: w => `${w.datum || ''} Helikoptereinsatz ${w.strasse || ''}`.trim() },
    kran:       { daten: ['adresse', 'termin', 'zusatz', 'pl', 'va'], pflicht: w => !w.datum ? 'Datum fehlt.' : !adresse(w) ? 'Adresse fehlt.' : '',
                  dateiname: w => `${w.datum || ''} Kraneinsatz ${w.strasse || ''}`.trim() }
  };
  const GROESSEN = [['fxs', 'Sehr klein'], ['fs', 'Klein'], ['', 'Normal'], ['fg', 'Gross'], ['fxl', 'Sehr gross']]; // Schriftgrössen (Klasse, Name)
  const GK = GROESSEN.map(g => g[0]).filter(Boolean);
  const FMT = ['fb', 'fi', 'fu', 'fl', ...GK]; // Format eines Chips: fett, kursiv, unterstrichen, Leuchtstift, Grösse

  const CSS = `
body{margin:0;background:#F5F7F9;color:#232B35;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;font-size:14px;line-height:1.4;}
*{box-sizing:border-box;}
.hidden{display:none!important;}
header.app{background:#323E4E;color:#fff;}
header.app .wrap{display:flex;align-items:center;gap:16px;padding:0 16px;}
header.app .brand h1{font-size:15px;margin:0;}
nav.subnav{background:#fff;border-bottom:1px solid #E1E5E9;} nav.subnav .wrap{display:flex;gap:2px;padding:0 16px;}
nav.subnav a{padding:12px 12px 10px;color:#6B7079;font-weight:600;text-decoration:none;font-size:13px;border-bottom:2px solid transparent;}
nav.subnav a.on{color:#323E4E;border-bottom-color:#323E4E;}
.loginwrap{min-height:70vh;display:flex;align-items:center;justify-content:center;}
.logincard{background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(35,43,53,.08),0 0 0 1px rgba(35,43,53,.04);padding:24px 22px;width:100%;max-width:340px;display:flex;flex-direction:column;gap:10px;}
.logincard h2{font-size:17px;margin:0 0 4px;color:#323E4E;}
.logincard label{font-size:12px;color:#6B7079;}
.logincard input{height:40px;border:1px solid #B9C0C8;border-radius:8px;padding:0 10px;font:inherit;font-size:15px;width:100%;}
.logincard button{all:unset;box-sizing:border-box;cursor:pointer;height:40px;border-radius:8px;background:#323E4E;color:#fff;font-weight:600;text-align:center;}
.logincard .status{font-size:12.5px;color:#6B7079;min-height:16px;} .logincard .status.err{color:#B4655F;}
.kgd-toast{position:fixed;left:50%;bottom:24px;transform:translateX(-50%);background:#323E4E;color:#fff;font-size:13px;padding:9px 14px;border-radius:8px;box-shadow:0 6px 20px rgba(0,0,0,.2);z-index:100;}
.kgd-toast.err{background:#B4655F;}
.kgd-btn{all:unset;box-sizing:border-box;cursor:pointer;height:34px;padding:0 13px;border-radius:8px;font-weight:600;font-size:13px;display:inline-flex;align-items:center;justify-content:center;gap:6px;white-space:nowrap;}
.kgd-btn.prim{background:#323E4E;color:#fff;} .kgd-btn.ghost{background:#fff;border:1px solid #D5DBE1;color:#323E4E;} .kgd-btn.ghost:hover{border-color:#4C5C70;}
.kgd-btn[disabled]{opacity:.45;cursor:default;}
.kgd-btn:focus-visible,.kgd-wb:focus-visible{outline:2px solid #323E4E;outline-offset:2px;}
.kgd-hinweis{font-size:12px;color:#6B7079;line-height:1.4;}
.kgd-t{width:100%;height:36px;border:1px solid #B9C0C8;border-radius:8px;padding:0 10px;font:inherit;font-size:14px;color:#232B35;background:#fff;}
.kgd-t:focus{outline:none;border-color:#323E4E;}
.kgd-tab{overflow-x:auto;border:1px solid #D5DBE1;border-radius:10px;background:#fff;}
.kgd-tab table{width:100%;border-collapse:collapse;font-size:13.5px;}
.kgd-tab th{text-align:left;font-size:11.5px;letter-spacing:.05em;text-transform:uppercase;color:#8B9097;font-weight:600;padding:8px 12px;border-bottom:1px solid #D5DBE1;white-space:nowrap;background:#F5F7F9;}
.kgd-tab td{padding:6px 12px;border-bottom:1px solid #EEF1F4;white-space:nowrap;}
.kgd-tab tr:last-child td{border-bottom:0;}
.kgd-tab td.akt{text-align:right;} .kgd-tab td.akt .kg-ibtn{margin-left:4px;}
/* Startseite */
.kgd-start{display:grid;grid-template-columns:230px minmax(0,1fr);min-height:calc(100vh - 100px);}
.kgd-ordner{background:#EEF1F4;border-right:1px solid #D5DBE1;padding:12px 8px;display:flex;flex-direction:column;gap:2px;}
.kgd-ordner .ueber{font-size:11.5px;letter-spacing:.06em;text-transform:uppercase;color:#8B9097;font-weight:600;padding:6px 10px;}
.kgd-oz{display:flex;align-items:center;gap:2px;border-radius:8px;}
.kgd-oz .griff{color:#A3B0BE;cursor:grab;display:inline-flex;padding:0 2px;flex:none;}
.kgd-oz.zieht{opacity:.4;} .kgd-oz.ueber-ziel{box-shadow:inset 0 2px 0 #323E4E;}
.kgd-oz .wahl{all:unset;box-sizing:border-box;cursor:pointer;flex:1;min-width:0;display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:8px;font-size:14px;color:#323E4E;}
.kgd-oz .wahl span{flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;} .kgd-oz .wahl small{color:#8B9097;font-size:12px;}
.kgd-oz .wahl:hover{background:#E3E7EC;}
.kgd-oz .wahl[aria-pressed="true"]{background:#fff;box-shadow:0 1px 3px rgba(35,43,53,.1);font-weight:600;}
.kgd-oz .wahl .fi{display:inline-flex;flex:none;}
.kgd-oz .aktion{display:flex;gap:3px;flex:none;opacity:.5;}
.kgd-oz:hover .aktion,.kgd-oz:focus-within .aktion{opacity:1;}
.kgd-neu{all:unset;cursor:pointer;color:#6B7079;font-size:13.5px;padding:8px 10px;margin-top:4px;border-radius:8px;}
.kgd-neu:hover{background:#E3E7EC;color:#323E4E;}
.kgd-tab tr.klick{cursor:pointer;} .kgd-tab tr.klick:hover td{background:#F5F7F9;}
.kgd-typen{padding:18px 22px;display:flex;flex-direction:column;gap:16px;min-width:0;max-width:1100px;}
.kgd-typen h2{margin:0;font-size:18px;color:#323E4E;}
.kgd-typliste{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,250px),1fr));gap:12px;}
.kgd-typ{all:unset;box-sizing:border-box;cursor:pointer;border:1px solid #D5DBE1;border-radius:10px;padding:14px;display:flex;gap:12px;align-items:flex-start;background:#fff;}
.kgd-typ:hover{border-color:#4C5C70;box-shadow:0 2px 8px rgba(20,28,38,.08);}
.kgd-typ .bl{width:34px;height:42px;border:1px solid #D5DBE1;border-radius:4px;display:flex;align-items:center;justify-content:center;flex:none;background:#F5F7F9;}
.kgd-typ b{display:block;font-size:14.5px;color:#323E4E;margin-bottom:2px;}
.kgd-typ small{font-size:12.5px;color:#6B7079;line-height:1.35;}
.kgd-leer{border:1px dashed #D5DBE1;border-radius:10px;padding:14px;color:#8B9097;font-size:13.5px;}
.kgd-zwtitel{font-size:12px;letter-spacing:.06em;text-transform:uppercase;color:#8B9097;font-weight:600;margin:6px 0 -6px;}
/* Dokument */
.kgd-flaeche{background:#E3E7EC;padding:24px 20px 48px;display:flex;flex-direction:column;align-items:center;gap:12px;position:relative;min-height:calc(100vh - 100px);}
.kgd-adminband{display:flex;align-items:center;gap:8px;padding:7px 16px;background:#F4CDD5;color:#7A2638;font-size:13px;font-weight:600;flex-wrap:wrap;}
.kgd-adminband span.t{flex:1;min-width:200px;}
.kgd-rand{width:760px;max-width:100%;container-type:inline-size;}
.kgd-blatt{background:#fff;min-height:calc(100cqw * 297 / 210);box-shadow:0 2px 14px rgba(20,28,38,.16);font-family:"Jost","Futura","Century Gothic",-apple-system,"Segoe UI",sans-serif;color:#232B35;display:flex;flex-direction:column;--b:clamp(9.5px,1.75cqw,13.5px);font-size:var(--b);line-height:1.5;}
.kgd-kopf{display:flex;justify-content:flex-end;padding:6cqw 9cqw 0;}
.kgd-logo{width:22cqw;}
.kgd-haupt{padding:7cqw 13cqw 2em;display:flex;flex-direction:column;flex:1;}
.kgd-ort{margin-bottom:3.2em;}
.kgd-ed{outline:none;}
.kgd-ed h2{font-size:1.32em;font-weight:600;color:#323E4E;margin:0 0 1em;line-height:1.3;}
.kgd-ed p{margin:0 0 1em;} .kgd-ed p:empty{min-height:1.5em;}
.kgd-ed ul,.kgd-ed ol{margin:-.4em 0 1em;padding-left:1.4em;} .kgd-ed li{margin:.1em 0;}
.kgd-pers{display:flex;flex-direction:column;margin-top:2em;}
.kgd-pers + .kgd-pers{margin-top:1.2em;}
.kgd-mail{color:#2F5C9A;text-decoration:underline;}
.kgd-fuss{padding:1em 9cqw 5cqw;text-align:center;font-size:.92em;}
.fb{font-weight:700;} .fi{font-style:italic;} .fu{text-decoration:underline;} .fl{background:#E8EDB0;}
.fxs{font-size:calc(var(--b) * .8);} .fs{font-size:calc(var(--b) * .9);} .fg{font-size:calc(var(--b) * 1.15);} .fxl{font-size:calc(var(--b) * 1.35);}
.kgd-mark .w{background:#D6E7F4;border-radius:3px;box-shadow:0 0 0 2px #D6E7F4;}
.kgd-mark .kgd-pers.w{box-shadow:0 0 0 6px #D6E7F4;}
.kgd-mark .w.fl{background:#E8EDB0;}
/* Daten-Fenster */
.kgd-schleier{position:absolute;inset:0;background:rgba(227,231,236,.4);z-index:4;}
.kgd-daten{position:absolute;left:50%;top:56px;transform:translateX(-50%);width:min(410px,calc(100% - 24px));background:#fff;border-radius:12px;box-shadow:0 18px 50px rgba(20,28,38,.28),0 0 0 1px rgba(35,43,53,.06);z-index:5;display:flex;flex-direction:column;}
.kgd-daten header{display:flex;align-items:center;gap:8px;padding:12px 14px 2px;}
.kgd-daten header b{flex:1;font-size:16px;color:#323E4E;}
.kgd-felder{padding:8px 14px 12px;display:flex;flex-direction:column;gap:10px;}
.kgd-daten footer{display:flex;gap:8px;padding:10px 14px 14px;border-top:1px solid #EEF1F4;}
.kgd-daten footer .prim{flex:1;}
.kgd-feld{display:flex;flex-direction:column;gap:3px;position:relative;}
.kgd-feld > label{font-size:12.5px;color:#4C5C70;font-weight:600;}
.kgd-feld small.opt{font-weight:400;color:#8B9097;}
.kgd-reihe{display:flex;gap:8px;align-items:flex-end;} .kgd-reihe > *{flex:1;min-width:0;}
.kgd-schalter{display:flex;align-items:center;gap:8px;font-size:13px;cursor:pointer;color:#4C5C70;height:26px;}
.kgd-schalter input{width:17px;height:17px;accent-color:#323E4E;}
.kgd-menue{position:absolute;left:0;right:0;top:100%;margin-top:4px;z-index:6;background:#fff;border:1px solid #D5DBE1;border-radius:8px;box-shadow:0 8px 24px rgba(20,28,38,.16);overflow:hidden;font-size:13.5px;max-height:320px;overflow-y:auto;}
.kgd-menue button{all:unset;box-sizing:border-box;cursor:pointer;display:flex;flex-direction:column;width:100%;padding:7px 10px;border-top:1px solid #EEF1F4;}
.kgd-menue button:hover,.kgd-menue button.akt{background:#F5F7F9;}
.kgd-menue small{color:#6B7079;font-size:12px;}
.kgd-menue .kopfzeile{padding:6px 10px;font-size:11.5px;color:#8B9097;background:#F5F7F9;}
/* Editor */
.kgd-wleiste{width:760px;max-width:100%;position:sticky;top:8px;z-index:3;background:#fff;border-radius:10px;box-shadow:0 2px 10px rgba(20,28,38,.14);padding:6px;display:flex;align-items:center;gap:2px;flex-wrap:wrap;}
.kgd-wb{all:unset;cursor:pointer;width:32px;height:32px;border-radius:6px;display:inline-flex;align-items:center;justify-content:center;color:#323E4E;box-sizing:border-box;}
.kgd-wb:hover{background:#F5F7F9;}
.kgd-wb svg{width:18px;height:18px;}
.kgd-wb.leucht{position:relative;} .kgd-wb.leucht::after{content:"";position:absolute;left:7px;right:7px;bottom:5px;height:3px;background:#D1DB5F;border-radius:1px;}
.kgd-sep{width:1px;height:22px;background:#D5DBE1;margin:0 4px;}
.kgd-wsel{height:32px;border:1px solid #D5DBE1;border-radius:6px;font:inherit;font-size:13px;color:#323E4E;padding:0 6px;background:#fff;}
.kgd-admin .kgd-ed{outline:1px dashed rgba(139,144,151,.8);outline-offset:8px;border-radius:2px;cursor:text;}
.kgd-admin .kgd-ed:focus{outline:2px solid #A63A52;}
.kgd-ph{font:inherit;color:#323E4E;border:1.5px solid #A3AE3A;border-radius:6px;padding:0 .3em;white-space:nowrap;cursor:grab;user-select:none;}
.kgd-phb{font-family:-apple-system,"Segoe UI",sans-serif;display:flex;align-items:center;gap:.6em;margin:1.2em 0 0;padding:.6em .9em;border:1.5px dashed #A3AE3A;background:#F6F8DF;border-radius:8px;font-size:.9em;color:#323E4E;cursor:grab;user-select:none;}
.kgd-phb b{font-weight:600;} .kgd-phb small{color:#6B7079;} .kgd-phb svg{flex:none;color:#7C8726;}
.kgd-ph.zieht,.kgd-phb.zieht{opacity:.4;}
.kgd-ph.sel{background:#B4D5FE;border-color:#2F5C9A;}
/* Dialoge, Drive-Status */
.kgd-dlgs{position:fixed;inset:0;background:rgba(35,43,53,.35);z-index:50;display:flex;align-items:flex-start;justify-content:center;padding:90px 12px 12px;}
.kgd-dlg{width:min(480px,100%);max-height:calc(100vh - 110px);overflow-y:auto;background:#fff;border-radius:12px;box-shadow:0 18px 50px rgba(20,28,38,.3);padding:18px;display:flex;flex-direction:column;gap:12px;}
.kgd-dlg h3{margin:0;font-size:17px;color:#323E4E;}
.kgd-dlg p{margin:0;font-size:14px;line-height:1.45;}
.kgd-dlg .knoepfe{display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap;}
.kgd-wahl{display:flex;flex-direction:column;gap:6px;}
.kgd-wahl label{display:flex;gap:10px;align-items:flex-start;border:1px solid #D5DBE1;border-radius:8px;padding:9px 10px;cursor:pointer;font-size:13.5px;}
.kgd-wahl label:has(input:checked){border-color:#323E4E;background:#F5F7F9;}
.kgd-wahl input{margin-top:2px;accent-color:#323E4E;}
.kgd-wahl b{color:#323E4E;} .kgd-wahl small{display:block;color:#6B7079;font-size:12px;margin-top:2px;}
.kgd-status{display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:600;padding:4px 9px;border-radius:99px;white-space:nowrap;text-decoration:none;}
.kgd-status.nein{background:#F5F7F9;color:#6B7079;border:1px solid #D5DBE1;}
.kgd-status.ja{background:#D3EBC7;color:#2E5A2F;}
.kgd-status.alt{background:#FAEBB0;color:#8A6410;}
.kgd-status svg{width:13px;height:13px;}
/* Drucken: nur das Blatt, A4 */
#kgdDruck{display:none;}
@page{size:A4;margin:0;}
@media print{
  body > *:not(#kgdDruck){display:none!important;}
  #kgdDruck{display:block!important;}
  body{background:#fff;}
}
.kgd-a4{width:210mm;container-type:inline-size;}
.kgd-a4 .kgd-blatt{box-shadow:none;height:296.5mm;min-height:0;overflow:hidden;--b:13.5px;}
@media (max-width:760px){
  .kgd-start{grid-template-columns:1fr;} .kgd-ordner{border-right:0;border-bottom:1px solid #D5DBE1;}
  .kgd-flaeche{padding:12px 8px 24px;} .kgd-typen{padding:14px 12px;}
}
`;

  const KGD = window.KGD = {
    ROLLEN, FELDER, TYPEN, esc, ic, lsGet, lsSet, datumKurz, adresse,
    sb: null, ich: null, personen: [], darfVorlagen: false, darfBriefe: false,

    toast(text, err){
      const t = document.createElement('div'); t.className = 'kgd-toast' + (err ? ' err' : ''); t.textContent = text;
      document.body.appendChild(t); setTimeout(() => t.remove(), err ? 5000 : 2000);
    },

    // Login + Rechte + Personen; danach fertig(main)
    async start(fertig){
      if(!$('kgd-css')){ const st = document.createElement('style'); st.id = 'kgd-css'; st.textContent = CSS; document.head.appendChild(st); }
      KG._sb = KG._sb || window.supabase.createClient('https://oalapdxinqlnzwxhyuzy.supabase.co', 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P');
      const sb = KGD.sb = KG._sb, main = $('appMain');
      const lo = $('logoutBtn'); if(lo) lo.addEventListener('click', async () => { await sb.auth.signOut(); location.reload(); });
      const { data: { session } } = await sb.auth.getSession();
      if(!session){ KGD.login(main, fertig); return; }
      const { data: b } = await sb.from('benutzer').select('rolle,aktiv,email,anzeigename').eq('id', session.user.id).maybeSingle();
      if(!b || !b.rolle || b.aktiv === false){ main.innerHTML = '<div class="loginwrap"><div class="logincard"><h2>Noch nicht freigeschaltet</h2><p class="kgd-hinweis">Dein Konto wartet auf Freischaltung durch einen Admin.</p></div></div>'; return; }
      KGD.ich = session.user.id;
      await (KG.ladeRechte ? KG.ladeRechte() : null);
      // ohne Gruppe (alte Konten): Vorlagen nur Admin, Briefe Admin + Büro
      const schalter = (k, alt) => { const r = KG.darf ? KG.darf('doku', k, 'an') : null; return r === null ? alt.includes(b.rolle) : r === 'J'; };
      KGD.darfVorlagen = schalter('vorlagen', ['admin']); KGD.darfBriefe = schalter('briefe', ['admin', 'buero_team']);
      if(KGD.darfBriefe) await KGD.ladePersonen();
      const ub = $('userbar'); if(ub){ ub.classList.remove('hidden'); const t = $('userbarText'); if(t) t.textContent = b.anzeigename || b.email || ''; }
      fertig(main);
    },
    // Personen = Benutzer mit Merkmalen (Verwaltung › Personen › Merkmale); rolle = wichtigstes Merkmal für den Brief
    async ladePersonen(){
      const { data, error } = await KGD.sb.rpc('doku_personen');
      if(error) KGD.toast('Personen konnten nicht geladen werden: ' + error.message, true);
      KGD.personen = (data || []).map(p => ({ ...p, merkmale: p.merkmale || [], rolle: ['projektleiter', 'bauleiter', 'vorarbeiter'].find(k => (p.merkmale || []).includes(k)) || '' }))
        .sort((a, b) => (a.name || '').localeCompare(b.name || '', 'de'));
    },

    login(main, fertig){
      main.innerHTML = `<div class="loginwrap"><div class="logincard"><h2>Anmelden</h2>
        <label for="loginEmail">E-Mail</label><input autocomplete="username" id="loginEmail" type="email">
        <label for="loginPassword">Passwort</label><input autocomplete="current-password" id="loginPassword" type="password">
        <button type="button" id="loginBtn">Anmelden</button><div class="status" id="loginStatus"></div></div></div>`;
      const los = async () => {
        $('loginStatus').textContent = 'Melde an …'; $('loginStatus').className = 'status';
        const { error } = await KGD.sb.auth.signInWithPassword({ email: $('loginEmail').value.trim(), password: $('loginPassword').value });
        if(error){ $('loginStatus').textContent = 'Login fehlgeschlagen: ' + error.message; $('loginStatus').className = 'status err'; return; }
        main.innerHTML = ''; KGD.start(fertig);
      };
      $('loginBtn').addEventListener('click', los);
      $('loginPassword').addEventListener('keydown', e => { if(e.key === 'Enter') los(); });
    },

    // Brief --------------------------------------------------------------------------------------
    chipHtml(k, fmt){
      const f = FELDER[k]; if(!f) return '';
      return f.block
        ? `<div class="kgd-phb" contenteditable="false" draggable="true" data-f="${k}">${ic('griff', 14)}<b>${esc(f.chip)}</b><small>${esc(f.info || '')}</small></div>`
        : `<span class="kgd-ph${fmt ? ' ' + fmt : ''}" contenteditable="false" draggable="true" data-f="${k}">${esc(f.chip)}</span>`;
    },
    inhalt(html, w, modus){
      const t = document.createElement('div'); t.innerHTML = KGD.sauber(html);
      t.querySelectorAll('[data-f]').forEach(el => {
        const k = el.dataset.f, f = FELDER[k]; if(!f){ el.remove(); return; }
        const fmt = FMT.filter(x => el.classList.contains(x)).join(' ');
        if(modus === 'admin'){ el.outerHTML = KGD.chipHtml(k, fmt); return; }
        if(f.block){ el.outerHTML = f.html(w); return; }
        const s = document.createElement('span'); s.className = ('w ' + fmt).trim(); s.textContent = f.wert(w); el.replaceWith(s);
      });
      return t.innerHTML;
    },
    brief(el, html, w, modus){
      el.innerHTML = `<div class="kgd-blatt${modus === 'fuellen' ? ' kgd-mark' : ''}">
        <div class="kgd-kopf"><img class="kgd-logo" src="/logo-gruen-blau.png" alt="Knechtgarten"></div>
        <div class="kgd-haupt"><div class="kgd-ort">Heimenschwand, ${heute()}</div>
          <div class="kgd-ed"${modus === 'admin' ? ' contenteditable="true" spellcheck="true"' : ''}>${KGD.inhalt(html, w, modus)}</div></div>
        <div class="kgd-fuss">Knechtgarten · Badhaus 42 · 3615 Heimenschwand<br>033 453 10 20 · info@knechtgarten.ch · www.knechtgarten.ch</div></div>`;
      return el.querySelector('.kgd-ed');
    },
    // Nur erlaubte Tags/Attribute behalten (Text kommt aus dem Editor oder Einfügen aus Word)
    sauber(html){
      const ERLAUBT = new Set(['H2', 'P', 'UL', 'OL', 'LI', 'B', 'STRONG', 'I', 'EM', 'U', 'SPAN', 'BR', 'DIV']);
      const t = document.createElement('div'); t.innerHTML = html || '';
      const lauf = n => [...n.children].forEach(c => {
        if(c.tagName === 'FONT'){ // Rest aus execCommand('fontSize'): ohne Grössenklasse = normal
          const s = document.createElement('span');
          s.append(...c.childNodes); c.replaceWith(s); c = s;
        }
        if(!ERLAUBT.has(c.tagName)){ c.replaceWith(...c.childNodes); lauf(n); return; }
        const f = c.getAttribute('data-f'), bg = (c.style && c.style.backgroundColor) || '';
        const kl = FMT.filter(x => c.classList.contains(x));
        [...c.attributes].forEach(a => c.removeAttribute(a.name));
        if(f && FELDER[f]){ c.setAttribute('data-f', f); if(kl.length) c.className = kl.join(' '); c.innerHTML = ''; return; }
        if(c.tagName === 'SPAN'){
          if(bg && bg !== 'transparent' && !/rgba\(0, 0, 0, 0\)/.test(bg) && !kl.includes('fl')) kl.push('fl');
          if(kl.length) c.className = kl.join(' ');
        }
        lauf(c);
      });
      lauf(t);
      return t.innerHTML;
    },

    // Vorlagen-Editor ----------------------------------------------------------------------------
    leisteHtml: () => `<div class="kgd-wleiste" id="kgdLeiste" role="toolbar" aria-label="Text formatieren">
        <select class="kgd-wsel" id="kgdFormat" aria-label="Absatz"><option value="p">Text</option><option value="h2">Titel</option></select><span class="kgd-sep"></span>
        <button type="button" class="kgd-wb" data-cmd="bold" title="Fett">${ic('fett', 18)}</button>
        <button type="button" class="kgd-wb" data-cmd="italic" title="Kursiv">${ic('kursiv', 18)}</button>
        <button type="button" class="kgd-wb" data-cmd="underline" title="Unterstrichen">${ic('unterstrichen', 18)}</button>
        <button type="button" class="kgd-wb leucht" data-cmd="leucht" title="Leuchtstift">${ic('leuchtstift', 18)}</button>
<span class="kgd-sep"></span>
        <select class="kgd-wsel" id="kgdGroesse" aria-label="Schriftgrösse" title="Schriftgrösse">${GROESSEN.map(([k, n]) => `<option value="${k}"${k ? '' : ' selected'}>${n}</option>`).join('')}</select><span class="kgd-sep"></span>
        <button type="button" class="kgd-wb" data-cmd="insertUnorderedList" title="Aufzählung">${ic('aufzaehlung', 18)}</button>
        <button type="button" class="kgd-wb" data-cmd="insertOrderedList" title="Nummerierung">${ic('nummerierung', 18)}</button><span class="kgd-sep"></span>
        <button type="button" class="kgd-wb" data-cmd="undo" title="Rückgängig">${ic('undo', 18)}</button>
        <span class="kgd-hinweis" style="margin-left:auto;padding-right:6px">Felder: ziehen zum Verschieben, anklicken zum Formatieren</span></div>`,
    editor(ed, leiste){
      let gezogen = null, auswahl = null;
      const merken = () => { const s = getSelection(); if(s.rangeCount && ed.contains(s.anchorNode)) auswahl = s.getRangeAt(0).cloneRange(); };
      ed.addEventListener('keyup', merken); ed.addEventListener('mouseup', merken);
      // Felder in der Markierung sichtbar hervorheben (Chips selbst lassen sich nicht markieren)
      const markierung = () => {
        if(!ed.isConnected){ document.removeEventListener('selectionchange', markierung); return; }
        const s = getSelection(), r = s.rangeCount && !s.isCollapsed && ed.contains(s.anchorNode) ? s.getRangeAt(0) : null;
        ed.querySelectorAll('.kgd-ph').forEach(c => c.classList.toggle('sel', !!r && r.intersectsNode(c)));
        // Grössen-Auswahl zeigt die Grösse an der Markierung
        if(s.rangeCount && ed.contains(s.anchorNode)){
          auswahl = s.getRangeAt(0).cloneRange();
          const n = s.anchorNode.nodeType === 3 ? s.anchorNode.parentElement : s.anchorNode;
          const g = n.closest && n.closest(GK.map(k => '.' + k).join(','));
          const sel = leiste.querySelector('#kgdGroesse'); if(sel) sel.value = g && ed.contains(g) ? GK.find(k => g.classList.contains(k)) : '';
        }
      };
      document.addEventListener('selectionchange', markierung);
      // Klick auf einen Chip markiert ihn ganz, damit Fett/Kursiv/Leuchtstift auf ihn wirken
      ed.addEventListener('click', e => {
        const c = e.target.closest('.kgd-ph'); if(!c) return;
        const r = document.createRange(); r.selectNode(c); const s = getSelection(); s.removeAllRanges(); s.addRange(r); auswahl = r.cloneRange();
      });
      // Eingefügter Text (z. B. aus Word) nur als reiner Text
      ed.addEventListener('paste', e => { e.preventDefault(); document.execCommand('insertText', false, (e.clipboardData || window.clipboardData).getData('text/plain')); });
      ed.addEventListener('dragstart', e => {
        const c = e.target.closest && e.target.closest('.kgd-ph,.kgd-phb'); if(!c){ e.preventDefault(); return; }
        gezogen = c; c.classList.add('zieht'); e.dataTransfer.effectAllowed = 'move'; e.dataTransfer.setData('text/plain', '');
      });
      ed.addEventListener('dragend', () => { if(gezogen) gezogen.classList.remove('zieht'); gezogen = null; });
      ed.addEventListener('dragover', e => { if(gezogen) e.preventDefault(); });
      ed.addEventListener('drop', e => {
        if(!gezogen) return; e.preventDefault();
        if(gezogen.classList.contains('kgd-phb')){
          // Blöcke landen zwischen Absätzen
          let ziel = document.elementFromPoint(e.clientX, e.clientY);
          while(ziel && ziel.parentElement !== ed) ziel = ziel.parentElement;
          if(ziel && ziel !== gezogen){ const r = ziel.getBoundingClientRect(); ed.insertBefore(gezogen, e.clientY > r.top + r.height / 2 ? ziel.nextSibling : ziel); }
        } else {
          let r = null;
          if(document.caretRangeFromPoint) r = document.caretRangeFromPoint(e.clientX, e.clientY);
          else if(document.caretPositionFromPoint){ const p = document.caretPositionFromPoint(e.clientX, e.clientY); if(p){ r = document.createRange(); r.setStart(p.offsetNode, p.offset); } }
          if(r && ed.contains(r.startContainer) && !gezogen.contains(r.startContainer) && !r.startContainer.closest?.('.kgd-phb')) r.insertNode(gezogen);
        }
        gezogen.classList.remove('zieht'); gezogen = null;
      });
      const chipsFormatieren = cmd => {
        const k = { bold: 'fb', italic: 'fi', underline: 'fu', leucht: 'fl' }[cmd], s = getSelection();
        if(!k || !s.rangeCount) return false;
        const r = s.getRangeAt(0), chips = [...ed.querySelectorAll('.kgd-ph')].filter(x => r.intersectsNode(x));
        if(!chips.length) return false;
        const alle = chips.every(x => x.classList.contains(k));
        chips.forEach(x => x.classList.toggle(k, !alle));
        const rest = r.cloneContents(); rest.querySelectorAll('.kgd-ph').forEach(x => x.remove());
        return !rest.textContent.trim(); // nur Chips markiert: kein execCommand
      };
      leiste.querySelectorAll('.kgd-wb').forEach(b => {
        b.addEventListener('mousedown', e => e.preventDefault());
        b.addEventListener('click', () => {
          const c = b.dataset.cmd;
          if(chipsFormatieren(c)) return;
          if(c === 'leucht'){
            const farbe = document.queryCommandValue('hiliteColor') || document.queryCommandValue('backColor') || '';
            document.execCommand('hiliteColor', false, /232, 237, 176|e8edb0/i.test(farbe) ? 'transparent' : '#E8EDB0');
          } else document.execCommand(c, false, null);
        });
      });
      // Schriftgrösse: Chips bekommen die Klasse, Text wird über <font size=7> markiert und zu <span class="…"> (Normal = ohne)
      leiste.querySelector('#kgdGroesse').addEventListener('change', e => {
        const k = e.target.value, s = getSelection();
        ed.focus(); if(auswahl){ s.removeAllRanges(); s.addRange(auswahl); }
        if(!s.rangeCount || s.isCollapsed){ KGD.toast('Zuerst Text markieren.'); e.target.value = ''; return; }
        const r = s.getRangeAt(0), setze = el => { GK.forEach(x => el.classList.remove(x)); if(k) el.classList.add(k); };
        [...ed.querySelectorAll('.kgd-ph')].filter(x => r.intersectsNode(x)).forEach(setze);
        const rest = r.cloneContents(); rest.querySelectorAll('.kgd-ph').forEach(x => x.remove());
        if(rest.textContent.trim()){
          document.execCommand('fontSize', false, '7');
          ed.querySelectorAll('font').forEach(f => {
            f.querySelectorAll('span').forEach(x => { if(!x.classList.contains('kgd-ph')){ GK.forEach(g => x.classList.remove(g)); if(!x.className) x.replaceWith(...x.childNodes); } });
            if(k){ const sp = document.createElement('span'); sp.className = k; sp.append(...f.childNodes); f.replaceWith(sp); }
            else f.replaceWith(...f.childNodes);
          });
        }
      });
      leiste.querySelector('#kgdFormat').addEventListener('change', e => {
        ed.focus(); if(auswahl){ const s = getSelection(); s.removeAllRanges(); s.addRange(auswahl); }
        document.execCommand('formatBlock', false, e.target.value);
      });
    },
    // Editor-Inhalt → Vorlage (Chips zurück zu leeren Platzhaltern)
    vorlageLesen(ed){
      const t = ed.cloneNode(true);
      t.querySelectorAll('.kgd-ph').forEach(c => { const s = document.createElement('span'); s.dataset.f = c.dataset.f; FMT.forEach(k => { if(c.classList.contains(k)) s.classList.add(k); }); c.replaceWith(s); });
      t.querySelectorAll('.kgd-phb').forEach(c => { const d = document.createElement('div'); d.dataset.f = c.dataset.f; c.replaceWith(d); });
      return KGD.sauber(t.innerHTML);
    },

    // Drucken / PDF ------------------------------------------------------------------------------
    a4(html, w){
      const box = document.createElement('div'); box.className = 'kgd-a4';
      KGD.brief(box, html, w, 'druck');
      return box;
    },
    drucken(html, w){
      let d = $('kgdDruck'); if(d) d.remove();
      d = document.createElement('div'); d.id = 'kgdDruck'; d.appendChild(KGD.a4(html, w)); document.body.appendChild(d);
      const bild = d.querySelector('img');
      const los = () => { window.print(); };
      if(bild && !bild.complete) bild.addEventListener('load', los, { once: true }); else los();
    },
    // PDF = Bild des A4-Blatts (html2canvas) auf einer A4-Seite (jsPDF); blob = nur erzeugen, nicht speichern
    async pdf(html, w, name, blob){
      const laden = src => new Promise((ok, fehler) => {
        const s = document.createElement('script'); s.src = src; s.onload = ok;
        s.onerror = () => fehler(new Error('PDF-Baustein konnte nicht geladen werden.')); document.head.appendChild(s);
      });
      if(!window.html2canvas) await laden('https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js');
      if(!window.jspdf) await laden('https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js');
      const halter = document.createElement('div'); halter.style.cssText = 'position:fixed;left:-10000px;top:0;';
      const box = KGD.a4(html, w); halter.appendChild(box); document.body.appendChild(halter);
      try {
        if(document.fonts && document.fonts.ready) await document.fonts.ready;
        const bild = box.querySelector('img'); if(bild && !bild.complete) await new Promise(ok => { bild.onload = bild.onerror = ok; });
        const canvas = await window.html2canvas(box.querySelector('.kgd-blatt'), { scale: 2, useCORS: true, backgroundColor: '#ffffff', logging: false });
        const doc = new window.jspdf.jsPDF({ unit: 'mm', format: 'a4', orientation: 'portrait' });
        doc.addImage(canvas.toDataURL('image/jpeg', 0.95), 'JPEG', 0, 0, 210, 297);
        if(blob) return doc;
        doc.save(KGD.dateiName(name));
      } finally { halter.remove(); }
    },
    dateiName: name => name.replace(/[\\/:*?"<>|]/g, '').trim() + '.pdf',

    // Dialog: html + Knöpfe [[text, art, wert]] → Promise mit wert (Schliessen/Esc = null)
    dialog(html, knoepfe, beimOeffnen){
      return new Promise(ok => {
        const s = document.createElement('div'); s.className = 'kgd-dlgs';
        s.innerHTML = `<div class="kgd-dlg" role="dialog">${html}<div class="knoepfe">${knoepfe.map(([t, a], i) => `<button type="button" class="kgd-btn ${a || 'ghost'}" data-i="${i}">${t}</button>`).join('')}</div></div>`;
        const zu = w => { s.remove(); document.removeEventListener('keydown', esc_); ok(w); };
        const esc_ = e => { if(e.key === 'Escape') zu(null); };
        s.addEventListener('click', e => { if(e.target === s) zu(null); const b = e.target.closest('[data-i]'); if(b) zu(knoepfe[+b.dataset.i][2]); });
        document.addEventListener('keydown', esc_);
        document.body.appendChild(s);
        if(beimOeffnen) beimOeffnen(s.querySelector('.kgd-dlg'), zu);
      });
    },

    // Google Drive (Ablage im Kundenordner) -----------------------------------------------------
    // Kundenbereich = geteilte Ablage «01_Kundendaten / Projekte»: Jahresordner > Kundenordner > 06-Notitzen
    DRIVE: { root: '0AEZm9ALFx3sgUk9PVA', unterordner: /^06\b/, clientId: '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com' },
    _gtoken: null,
    async googleToken(){
      if(KGD._gtoken && KGD._gtoken.bis > Date.now() + 60000) return KGD._gtoken.wert;
      const { data, error } = await KGD.sb.functions.invoke('doku-google', { body: { aktion: 'token' } });
      if(error) throw new Error('Google-Verbindung: ' + (error.message || error));
      if(!data || !data.verbunden) return null;
      KGD._gtoken = { wert: data.accessToken, bis: Date.now() + (data.expiresIn || 3000) * 1000 };
      return data.accessToken;
    },
    gsiLaden(){
      if(window.google && google.accounts && google.accounts.oauth2) return Promise.resolve();
      return new Promise((ok, fehler) => { const s = document.createElement('script'); s.src = 'https://accounts.google.com/gsi/client'; s.onload = ok; s.onerror = () => fehler(new Error('Google-Anmeldung konnte nicht geladen werden.')); document.head.appendChild(s); });
    },
    // muss direkt aus einem Klick kommen (Popup); gsiLaden() vorher erledigen
    googleVerbinden(){
      return new Promise((ok, fehler) => {
        const c = google.accounts.oauth2.initCodeClient({ client_id: KGD.DRIVE.clientId, scope: 'https://www.googleapis.com/auth/drive', ux_mode: 'popup',
          callback: async r => {
            if(r.error){ fehler(new Error('Google: ' + r.error)); return; }
            const { data, error } = await KGD.sb.functions.invoke('doku-google', { body: { aktion: 'tauschen', code: r.code } });
            if(error || !data || data.error){ fehler(new Error('Google-Verbindung: ' + ((data && data.error) || (error && error.message) || 'unbekannter Fehler'))); return; }
            KGD._gtoken = { wert: data.accessToken, bis: Date.now() + (data.expiresIn || 3000) * 1000 }; ok(data.accessToken);
          },
          error_callback: e => fehler(new Error(e && e.type === 'popup_closed' ? 'Google-Fenster geschlossen.' : 'Google-Anmeldung abgebrochen.')) });
        c.requestCode();
      });
    },
    async gapi(pfad, opt = {}){
      const t = await KGD.googleToken(); if(!t) throw new Error('Nicht mit Google verbunden.');
      const r = await fetch((pfad.startsWith('http') ? '' : 'https://www.googleapis.com/drive/v3/') + pfad, { ...opt, headers: { Authorization: 'Bearer ' + t, ...(opt.headers || {}) } });
      const d = await r.json().catch(() => ({}));
      if(!r.ok) throw new Error('Google Drive: ' + ((d.error && d.error.message) || r.status));
      return d;
    },
    async ordnerListe(q){
      const p = new URLSearchParams({ q: `mimeType='application/vnd.google-apps.folder' and trashed=false and (${q})`, corpora: 'drive', driveId: KGD.DRIVE.root,
        includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: 'files(id,name,parents,modifiedTime)', pageSize: '100' });
      return (await KGD.gapi('files?' + p)).files || [];
    },
    // Kundenordner suchen: Name/Firma, Ort und Strasse gegen die Ordnernamen in den Jahresordnern
    async ordnerVorschlag(w){
      const jahre = (await KGD.ordnerListe(`'${KGD.DRIVE.root}' in parents`)).filter(f => /^\d{4}$/.test(f.name));
      const jahrVon = new Map(jahre.map(j => [j.id, j.name]));
      const woerter = s => String(s || '').toLowerCase().split(/[^a-zäöüéèàß0-9-]+/i).filter(x => x.length >= 3 && !/^\d+$/.test(x) && !['und', 'gmbh', 'ag', 'familie', 'herr', 'frau'].includes(x));
      const namen = woerter(w.kunde_name), orte = woerter(ortOhnePlz(w.ort)), strassen = woerter(String(w.strasse || '').replace(/\d.*$/, ''));
      const alle = [...new Set([...namen, ...orte, ...strassen])].slice(0, 8);
      if(!alle.length) return [];
      const q = alle.map(x => `name contains '${x.replace(/'/g, "\\'")}'`).join(' or ');
      const treffer = (await KGD.ordnerListe(q)).filter(f => (f.parents || []).some(p => jahrVon.has(p)));
      const jahrSoll = (w.datum || '').slice(0, 4) || String(new Date().getFullYear());
      return treffer.map(f => {
        const n = f.name.toLowerCase(), jahr = jahrVon.get(f.parents.find(p => jahrVon.has(p))), gruende = [];
        let punkte = 0;
        if(namen.some(x => n.includes(x))){ punkte += 4; gruende.push('Name passt'); }
        if(orte.some(x => n.includes(x))){ punkte += 2; gruende.push('Ort passt'); }
        if(strassen.some(x => n.includes(x))){ punkte += 2; gruende.push('Strasse passt'); }
        if(jahr === jahrSoll){ punkte += 1; gruende.push('Jahr ' + jahr); }
        return { id: f.id, name: f.name, jahr, punkte, gruende, geaendert: f.modifiedTime };
      }).sort((a, b) => b.punkte - a.punkte || (b.jahr || '').localeCompare(a.jahr || '') || (b.geaendert || '').localeCompare(a.geaendert || '')).slice(0, 6);
    },
    // Unterordner 06-Notitzen im Kundenordner (fehlt er: Kundenordner selbst)
    async zielOrdner(kundenOrdner){
      const kinder = await KGD.ordnerListe(`'${kundenOrdner.id}' in parents`);
      const u = kinder.find(k => KGD.DRIVE.unterordner.test(k.name));
      return u ? { id: u.id, pfad: `${kundenOrdner.jahr ? kundenOrdner.jahr + ' › ' : ''}${kundenOrdner.name} › ${u.name}` }
               : { id: kundenOrdner.id, pfad: `${kundenOrdner.jahr ? kundenOrdner.jahr + ' › ' : ''}${kundenOrdner.name}` };
    },
    async ordnerAusLink(text){
      const m = String(text).match(/folders\/([\w-]{10,})/) || String(text).match(/^([\w-]{20,})$/);
      if(!m) throw new Error('Das ist kein Link auf einen Drive-Ordner.');
      const f = await KGD.gapi(`files/${m[1]}?supportsAllDrives=true&fields=id,name,mimeType`);
      if(f.mimeType !== 'application/vnd.google-apps.folder') throw new Error('Der Link zeigt nicht auf einen Ordner.');
      return { id: f.id, pfad: f.name };
    },
    // PDF hochladen (neu oder bestehende Datei ersetzen); gibt { id, link } zurück
    async hochladen(blob, name, ordnerId, ersetzenId){
      if(ersetzenId){
        const d = await KGD.gapi(`https://www.googleapis.com/upload/drive/v3/files/${ersetzenId}?uploadType=media&supportsAllDrives=true&fields=id,webViewLink`, { method: 'PATCH', headers: { 'Content-Type': 'application/pdf' }, body: blob });
        await KGD.gapi(`files/${ersetzenId}?supportsAllDrives=true`, { method: 'PATCH', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name }) });
        return { id: d.id, link: d.webViewLink };
      }
      const form = new FormData();
      form.append('metadata', new Blob([JSON.stringify({ name, parents: [ordnerId], mimeType: 'application/pdf' })], { type: 'application/json' }));
      form.append('file', blob);
      const d = await KGD.gapi('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,webViewLink', { method: 'POST', body: form });
      return { id: d.id, link: d.webViewLink };
    },
    driveStatus(dok, werte){
      if(!dok || !dok.drive_datei_id) return { art: 'nein', text: 'nicht im Drive' };
      if(werte && dok.drive_stand !== JSON.stringify(werte)) return { art: 'alt', text: 'geändert seit Ablage' };
      return { art: 'ja', text: 'im Drive', link: 'https://drive.google.com/file/d/' + dok.drive_datei_id + '/view' };
    }
  };
})();
