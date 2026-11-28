/* kg-verlauf.js – Zurück / Vorwärts / Verlauf für alle Tools (2026-11-28)
   Grundlage: Tabelle «verlauf» (Datenbank-Trigger schreiben jede Änderung mit, vorher/nachher)
   und die Funktion verlauf_anwenden(ids, 'zurueck'|'vor', erzwingen).

   Einbinden nach kg-stil.js:  <script src="/kg-verlauf.js?v=1"></script>
   Start nach dem Login:
     KG.verlauf.start({
       sb,                         // Supabase-Client des Tools
       bereich: 'planer',          // 'planer' | 'offerte'
       bezug: () => offerteId,     // optional: nur Einträge dieser Offerte (null = Knöpfe aus)
       neuLaden: async () => {},   // Daten frisch laden und zeichnen
       beschreibe: liste => ({ was, detail }),   // Text zu einem Schritt (Liste von Verlauf-Einträgen)
       ganz: 'Ganzen Planer',      // Beschriftung «… auf HH:MM zurücksetzen»
       ganzNurAdmin: true,         // ganzen Stand zurücksetzen nur für Admin
       vorschau: async nachher => {},   // optional: Stand ohne die Einträge «nachher» zeigen (nur Ansicht)
       vorschauEnde: async () => {}
     });
   Knöpfe [Zurück][Verlauf][Vorwärts] kommen links vor den Tool-Umschalter. Tasten: Ctrl+Z, Ctrl+Y / Ctrl+Shift+Z. */
(function(){
  const KG = window.KG = window.KG || {};
  const ic = (n, s) => KG.icon ? KG.icon(n, s) : '';
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const LUECKE = 2000; // ms: Einträge derselben Person mit kleinerem Abstand = ein Schritt

  const css = `
.kgv-knoepfe{display:inline-flex;align-items:center;gap:1px;height:34px;padding:0 2px;border-radius:9px;background:rgba(255,255,255,.08);flex-shrink:0;}
.kgv-knoepfe button{all:unset;box-sizing:border-box;cursor:pointer;width:30px;height:30px;display:flex;align-items:center;justify-content:center;border-radius:7px;color:#fff;}
.kgv-knoepfe button:hover:not(:disabled){background:rgba(255,255,255,.14);}
.kgv-knoepfe button:disabled{color:rgba(255,255,255,.32);cursor:default;}
.kgv-knoepfe button.on{background:#D1DB5F;color:#323E4E;}
.kgv-knoepfe svg{width:18px;height:18px;}
.kgv-leiste{position:fixed;top:0;right:0;bottom:0;width:380px;max-width:100vw;background:#fff;border-left:1px solid #DDE2E8;box-shadow:-12px 0 30px rgba(50,62,78,.12);z-index:9000;display:flex;flex-direction:column;font-size:13px;color:#323E4E;}
.kgv-kopf{display:flex;align-items:center;gap:8px;padding:14px 16px 8px;}
.kgv-kopf b{font-size:16px;flex:1;}
.kgv-kopf .kgv-sub{display:block;font-size:12px;font-weight:400;color:#6B7178;}
.kgv-zu{all:unset;cursor:pointer;width:26px;height:26px;border:1px solid #DDE2E8;border-radius:50%;display:flex;align-items:center;justify-content:center;color:#8B9097;}
.kgv-zu svg{width:14px;height:14px;}
.kgv-chips{display:flex;gap:6px;padding:0 16px 10px;}
.kgv-chips button{all:unset;cursor:pointer;font-size:12px;padding:4px 11px;border-radius:999px;border:1px solid #DDE2E8;background:#fff;}
.kgv-chips button.on{background:#323E4E;border-color:#323E4E;color:#fff;}
.kgv-band{margin:0 12px 8px;padding:10px 12px;border-radius:8px;background:#D6E7F4;display:flex;flex-direction:column;gap:8px;}
.kgv-band .kgv-bt{display:flex;flex-wrap:wrap;gap:6px;}
.kgv-liste{flex:1;overflow-y:auto;padding:0 8px 12px;}
.kgv-tag{font-size:11px;font-weight:700;letter-spacing:.06em;text-transform:uppercase;color:#8B9097;padding:14px 8px 6px;}
.kgv-s{padding:8px;border-radius:8px;margin-bottom:2px;cursor:pointer;display:flex;gap:10px;align-items:flex-start;}
.kgv-s:hover{background:#F5F7F9;} .kgv-s.sel{background:#D6E7F4;}
.kgv-s.rueck{opacity:.6;}
.kgv-s .kgv-z{font-weight:700;width:38px;flex-shrink:0;padding-top:2px;font-size:12.5px;}
.kgv-s .kgv-av{width:22px;height:22px;border-radius:50%;flex-shrink:0;background:#8B9097;color:#fff;font-size:11px;font-weight:700;display:flex;align-items:center;justify-content:center;}
.kgv-s .kgv-av.ich{background:#323E4E;}
.kgv-s .kgv-t{display:flex;flex-direction:column;gap:2px;line-height:1.35;min-width:0;}
.kgv-s .kgv-d{color:#6B7178;font-size:12px;}
.kgv-s .kgv-eins{margin-top:6px;}
.kgv-btn{all:unset;box-sizing:border-box;cursor:pointer;font-size:12px;font-weight:600;padding:5px 11px;border-radius:999px;border:1px solid #323E4E;background:#fff;color:#323E4E;}
.kgv-btn.prim{background:#323E4E;color:#fff;}
.kgv-btn .kgv-adm{font-size:10.5px;padding:1px 6px;border-radius:999px;background:#D1DB5F;color:#323E4E;margin-left:6px;}
.kgv-fuss{padding:10px 16px;border-top:1px solid #EEF1F4;font-size:11.5px;color:#6B7178;}
.kgv-mehr{display:block;margin:10px auto;}
.kgv-ovl{position:fixed;inset:0;background:rgba(50,62,78,.35);z-index:9500;display:flex;align-items:center;justify-content:center;}
.kgv-dlg{width:440px;max-width:calc(100vw - 32px);background:#fff;border-radius:12px;padding:20px 22px;box-shadow:0 20px 50px rgba(0,0,0,.25);display:flex;flex-direction:column;gap:12px;font-size:13.5px;color:#323E4E;}
.kgv-dlg b.kgv-h{font-size:17px;}
.kgv-dlg .kgv-l{background:#F5F7F9;border-radius:8px;padding:10px 12px;font-size:12.5px;max-height:200px;overflow:auto;display:flex;flex-direction:column;gap:3px;}
.kgv-dlg .kgv-bt{display:flex;justify-content:flex-end;gap:8px;}
.kgv-dlg .kgv-bt button{all:unset;cursor:pointer;padding:8px 14px;border-radius:8px;font-weight:600;border:1px solid #DDE2E8;}
.kgv-dlg .kgv-bt button.ja{background:#323E4E;color:#fff;border-color:#323E4E;}
.kgv-toast{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);background:#323E4E;color:#fff;border-radius:8px;padding:10px 16px;font-size:13px;z-index:9600;}
.kgv-toast.err{background:#B23B3B;}
@media (max-width:700px){.kgv-knoepfe{display:none;}}`;

  let O = null, ME = null, START = null, NAMEN = {}, ADMIN = false;
  let schritte = [], ST = {}, REDO = [], grenze = 0, offen = false, filterIch = false, sel = null, liste = [], limit = 300, laeuft = false;

  function toast(t, err){ const d = document.createElement('div'); d.className = 'kgv-toast' + (err ? ' err' : ''); d.textContent = t; document.body.appendChild(d); setTimeout(() => d.remove(), err ? 6000 : 2600); }
  function frage(titel, html, ja){ return new Promise(res => {
    const o = document.createElement('div'); o.className = 'kgv-ovl';
    o.innerHTML = `<div class="kgv-dlg" role="dialog" aria-label="${esc(titel)}"><b class="kgv-h">${esc(titel)}</b>${html}<div class="kgv-bt"><button type="button" data-n>Abbrechen</button><button type="button" class="ja" data-j>${esc(ja)}</button></div></div>`;
    const fertig = v => { o.remove(); removeEventListener('keydown', k, true); res(v); };
    const k = e => { if(e.key === 'Escape'){ e.stopPropagation(); fertig(false); } };
    o.addEventListener('click', e => { if(e.target === o || e.target.closest('[data-n]')) fertig(false); else if(e.target.closest('[data-j]')) fertig(true); });
    addEventListener('keydown', k, true); document.body.appendChild(o); o.querySelector('[data-j]').focus();
  }); }

  const zeitTxt = z => new Date(z).toLocaleTimeString('de-CH', { hour: '2-digit', minute: '2-digit' });
  const tagTxt = z => { const d = new Date(z), h = new Date(); const t0 = new Date(h.getFullYear(), h.getMonth(), h.getDate()).getTime(), t = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
    const w = d.toLocaleDateString('de-CH', { weekday: 'short', day: 'numeric', month: 'numeric' }); return t === t0 ? 'Heute · ' + w : t === t0 - 864e5 ? 'Gestern · ' + w : w; };
  const name = id => NAMEN[id] || (id === ME ? 'Ich' : 'Unbekannt');

  // Einträge zu Schritten bündeln (gleiche Person, Abstand ≤ 2 s); Liste aufsteigend nach id
  function buendeln(es){
    const out = []; let akt = null;
    es.forEach(e => { const t = +new Date(e.zeit);
      if(akt && akt.wer === e.benutzer_id && akt.rueck === e.rueck && t - akt.bis <= LUECKE){ akt.e.push(e); akt.bis = t; akt.max = e.id; }
      else { akt = { wer: e.benutzer_id, rueck: e.rueck, von: t, bis: t, min: e.id, max: e.id, e: [e] }; out.push(akt); } });
    return out;
  }
  function abfrage(q){ q = q.eq('bereich', O.bereich); const b = O.bezug ? O.bezug() : null; if(O.bezug) q = b ? q.eq('bezug_id', b) : q.eq('bezug_id', '00000000-0000-0000-0000-000000000000'); return q; }
  const txt = s => { try { return O.beschreibe(s.e) || { was: 'Änderung', detail: '' }; } catch(e){ return { was: 'Änderung', detail: '' }; } };

  // --- eigene Schritte (Zurück/Vorwärts) ---
  async function eigeneLaden(){
    if(!ME) return;
    const { data, error } = await abfrage(O.sb.from('verlauf').select('id,zeit,benutzer_id,tabelle,datensatz_id,aktion,alt,neu,rueck,tx')).eq('benutzer_id', ME).eq('rueck', false).gte('zeit', START).order('id').limit(1000);
    if(error) return;
    schritte = buendeln(data || []);
    const maxId = data?.length ? data[data.length - 1].id : 0;
    if(REDO.length && maxId > grenze){ REDO.forEach(k => ST[k] = 'verworfen'); REDO = []; }
    knoepfe();
  }
  const undoSchritt = () => { for(let i = schritte.length - 1; i >= 0; i--) if(!ST[schritte[i].min]) return schritte[i]; return null; };
  const redoSchritt = () => REDO.length ? schritte.find(s => s.min === REDO[REDO.length - 1]) : null;

  async function anwenden(ids, richtung, erzwingen){
    const { data, error } = await O.sb.rpc('verlauf_anwenden', { ids, richtung, erzwingen: !!erzwingen });
    if(error){ toast('Fehler: ' + error.message, true); return false; }
    if(data?.ok) return true;
    if(data?.konflikte){
      const n = data.konflikte.length;
      if(!await frage('Inzwischen geändert', `<span>${n === 1 ? 'Ein Eintrag wurde' : n + ' Einträge wurden'} seither von jemand anderem oder in einem späteren Schritt geändert. Trotzdem zurücksetzen? Die späteren Änderungen an ${n === 1 ? 'diesem Eintrag gehen' : 'diesen Einträgen gehen'} dabei verloren.</span>`, 'Trotzdem')) return false;
      return anwenden(ids, richtung, true);
    }
    toast('Nicht alles ging: ' + (data?.fehler || 'unbekannt'), true); return false;
  }
  async function zurueck(){
    if(laeuft) return; const s = undoSchritt(); if(!s) return; laeuft = true;
    try {
      const ids = s.e.map(e => e.id).sort((a, b) => b - a);
      if(!await anwenden(ids, 'zurueck')) return;
      grenze = Math.max(grenze, ...schritte.map(x => x.max)); ST[s.min] = 'zurueck'; REDO.push(s.min);
      toast('Rückgängig: ' + txt(s).was); await O.neuLaden(); await eigeneLaden(); if(offen) await listeLaden();
    } finally { laeuft = false; }
  }
  async function vor(){
    if(laeuft) return; const s = redoSchritt(); if(!s) return; laeuft = true;
    try {
      const ids = s.e.map(e => e.id).sort((a, b) => a - b);
      if(!await anwenden(ids, 'vor')) return;
      REDO.pop(); delete ST[s.min];
      toast('Wiederholt: ' + txt(s).was); await O.neuLaden(); await eigeneLaden(); if(offen) await listeLaden();
    } finally { laeuft = false; }
  }

  // --- Knöpfe in der Leiste ---
  let box = null;
  function einbauen(){
    if(box && document.contains(box)) return true;
    const tw = document.querySelector('header.app .kg-tw'); if(!tw) return false;
    box = document.createElement('div'); box.className = 'kgv-knoepfe';
    box.innerHTML = `<button type="button" data-v="z" aria-label="Rückgängig">${ic('schrittZurueck', 18)}</button><button type="button" data-v="l" aria-label="Verlauf" title="Verlauf">${ic('verlauf', 18)}</button><button type="button" data-v="v" aria-label="Wiederholen">${ic('schrittVor', 18)}</button>`;
    box.addEventListener('click', e => { const b = e.target.closest('button'); if(!b) return; const v = b.dataset.v; if(v === 'z') zurueck(); else if(v === 'v') vor(); else umschalten(); });
    tw.parentNode.insertBefore(box, tw); knoepfe(); return true;
  }
  function knoepfe(){
    if(!box) return;
    const u = undoSchritt(), r = redoSchritt(), bz = !O.bezug || !!O.bezug();
    const bu = box.querySelector('[data-v="z"]'), br = box.querySelector('[data-v="v"]'), bl = box.querySelector('[data-v="l"]');
    bu.disabled = !u || !bz; bu.title = u ? 'Rückgängig: ' + txt(u).was + ' (Ctrl+Z)' : 'Nichts rückgängig zu machen';
    br.disabled = !r || !bz; br.title = r ? 'Wiederholen: ' + txt(r).was + ' (Ctrl+Y)' : 'Nichts zu wiederholen';
    bl.disabled = !bz; bl.classList.toggle('on', offen);
  }

  // --- Verlauf-Leiste ---
  let el = null;
  async function umschalten(){ offen ? schliessen() : await oeffnen(); }
  async function oeffnen(){
    offen = true; sel = null; limit = 300;
    if(!el){ el = document.createElement('aside'); el.className = 'kgv-leiste'; el.setAttribute('aria-label', 'Verlauf'); document.body.appendChild(el); el.addEventListener('click', klick); }
    el.hidden = false; el.innerHTML = '<div class="kgv-kopf"><b>Verlauf</b></div><div class="kgv-liste" style="padding:16px">Lädt …</div>';
    knoepfe(); await listeLaden();
  }
  async function schliessen(){ offen = false; if(el) el.hidden = true; knoepfe(); if(sel && O.vorschau) await O.vorschauEnde?.(); sel = null; }
  async function listeLaden(){
    const { data, error } = await abfrage(O.sb.from('verlauf').select('id,zeit,benutzer_id,tabelle,datensatz_id,aktion,alt,neu,rueck,tx')).order('id', { ascending: false }).limit(limit);
    if(error){ el.querySelector('.kgv-liste').textContent = 'Fehler: ' + error.message; return; }
    let es = data || [];
    if(O.bezug && es.length){ // bei Offerten: mitgelöschte Unterzeilen (ohne Bezug) aus denselben Transaktionen dazunehmen
      const txs = [...new Set(es.map(e => e.tx))].slice(0, 200);
      const { data: d2 } = await O.sb.from('verlauf').select('id,zeit,benutzer_id,tabelle,datensatz_id,aktion,alt,neu,rueck,tx').eq('bereich', O.bereich).is('bezug_id', null).in('tx', txs);
      if(d2?.length) es = es.concat(d2).sort((a, b) => b.id - a.id);
    }
    liste = buendeln([...es].reverse()).reverse();
    zeichnen();
  }
  function zeichnen(){
    if(!el || !offen) return;
    const b = O.bezug ? O.bezug() : null;
    const l = filterIch ? liste.filter(s => s.wer === ME) : liste;
    const s = sel != null ? liste.find(x => x.max === sel) : null;
    const nach = s ? liste.filter(x => x.max > s.max) : [];
    const darfGanz = !O.ganzNurAdmin || ADMIN;
    let h = `<div class="kgv-kopf"><b>Verlauf${O.bezug ? '<span class="kgv-sub">nur diese ' + esc(O.bezugName || 'Offerte') + '</span>' : ''}</b><button type="button" class="kgv-zu" data-a="zu" aria-label="Verlauf schliessen">${ic('x', 14)}</button></div>
      <div class="kgv-chips"><button type="button" data-a="alle" class="${filterIch ? '' : 'on'}">Alle</button><button type="button" data-a="ich" class="${filterIch ? 'on' : ''}">Nur meine</button></div>`;
    if(s){
      const n = nach.reduce((a, x) => a + 1, 0), wer = [...new Set(nach.map(x => name(x.wer)))];
      h += `<div class="kgv-band"><span><b>${O.vorschau ? 'Vorschau: ' : ''}Stand von ${esc(tagTxt(s.bis).split(' · ')[0].toLowerCase())} ${zeitTxt(s.bis)}</b>${O.vorschau ? ' – nur Ansicht.' : ''}<br><span style="color:#4A5460">${n ? `${n} ${n === 1 ? 'Änderung' : 'Änderungen'} seither${wer.length ? ' (' + esc(wer.join(', ')) + ')' : ''}` : 'Das ist der aktuelle Stand.'}</span></span>
        <div class="kgv-bt"><button type="button" class="kgv-btn" data-a="jetzt">Zurück zu jetzt</button>${n && darfGanz ? `<button type="button" class="kgv-btn prim" data-a="ganz">${esc(O.ganz || 'Alles')} auf ${zeitTxt(s.bis)} zurücksetzen${O.ganzNurAdmin ? '<span class="kgv-adm">Admin</span>' : ''}</button>` : ''}</div></div>`;
    }
    h += '<div class="kgv-liste">';
    if(O.bezug && !b) h += '<div style="padding:16px;color:#6B7178">Erst eine Offerte öffnen.</div>';
    else if(!l.length) h += '<div style="padding:16px;color:#6B7178">Noch keine Änderungen.</div>';
    let tag = '';
    l.forEach(x => {
      const t = tagTxt(x.bis); if(t !== tag){ tag = t; h += `<div class="kgv-tag">${esc(t)}</div>`; }
      const d = txt(x), on = sel === x.max;
      h += `<div class="kgv-s${on ? ' sel' : ''}${x.rueck ? ' rueck' : ''}" data-s="${x.max}"><span class="kgv-z">${zeitTxt(x.bis)}</span><span class="kgv-av${x.wer === ME ? ' ich' : ''}" title="${esc(name(x.wer))}">${esc(name(x.wer)[0] || '?')}</span>
        <span class="kgv-t"><span><b>${esc(name(x.wer))}</b> · ${esc(d.was)}${x.rueck ? ' <i style="color:#6B7178">(Zurück/Wiederherstellen)</i>' : ''}</span>${d.detail ? `<span class="kgv-d">${esc(d.detail)}</span>` : ''}${x.e.length > 1 ? `<span class="kgv-d">${x.e.length} Einträge</span>` : ''}
        ${on ? `<span class="kgv-eins"><button type="button" class="kgv-btn" data-a="eins">Nur diese Änderung zurücknehmen</button></span>` : ''}</span></div>`;
    });
    if(liste.length >= limit - 5) h += '<button type="button" class="kgv-btn kgv-mehr" data-a="mehr">Ältere laden</button>';
    h += '</div><div class="kgv-fuss">Jede Änderung wird mitgeschrieben und 90 Tage aufbewahrt.</div>';
    el.innerHTML = h;
  }
  async function klick(e){
    const a = e.target.closest('[data-a]')?.dataset.a, sz = e.target.closest('[data-s]');
    if(a === 'zu') return schliessen();
    if(a === 'alle' || a === 'ich'){ filterIch = a === 'ich'; return zeichnen(); }
    if(a === 'mehr'){ limit += 300; return listeLaden(); }
    if(a === 'jetzt'){ sel = null; zeichnen(); if(O.vorschau) await O.vorschauEnde?.(); return; }
    if(a === 'eins'){
      const s = liste.find(x => x.max === sel); if(!s) return;
      if(!await anwenden(s.e.map(x => x.id).sort((p, q) => q - p), 'zurueck')) return;
      sel = null; if(O.vorschau) await O.vorschauEnde?.(); else await O.neuLaden();
      toast('Zurückgenommen: ' + txt(s).was); await listeLaden(); await eigeneLaden(); return;
    }
    if(a === 'ganz'){
      const s = liste.find(x => x.max === sel); if(!s) return;
      const nach = liste.filter(x => x.max > s.max);
      const zeilen = nach.slice(0, 40).map(x => `<span><b>${zeitTxt(x.bis)}</b> · ${esc(name(x.wer))} · ${esc(txt(x).was)}</span>`).join('') + (nach.length > 40 ? `<span>… und ${nach.length - 40} weitere</span>` : '');
      if(!await frage(`${O.ganz || 'Alles'} auf ${zeitTxt(s.bis)} zurücksetzen?`, `<span>Diese ${nach.length} ${nach.length === 1 ? 'Änderung geht' : 'Änderungen gehen'} dabei verloren:</span><div class="kgv-l">${zeilen}</div><span style="font-size:12px;color:#6B7178">Auch das Zurücksetzen steht danach im Verlauf und lässt sich so wieder rückgängig machen.</span>`, 'Zurücksetzen')) return;
      const ids = nach.flatMap(x => x.e.map(y => y.id)).sort((p, q) => q - p);
      if(!await anwenden(ids, 'zurueck', true)) return;
      sel = null; if(O.vorschau) await O.vorschauEnde?.(); else await O.neuLaden();
      toast(`Auf ${zeitTxt(s.bis)} zurückgesetzt`); await listeLaden(); await eigeneLaden(); return;
    }
    if(sz){
      const m = +sz.dataset.s; sel = sel === m ? null : m; zeichnen();
      if(O.vorschau){ if(sel == null) await O.vorschauEnde?.(); else { const nach = liste.filter(x => x.max > sel).flatMap(x => x.e); await O.vorschau(nach); } }
    }
  }

  // --- Start ---
  KG.verlauf = {
    async start(opt){
      O = opt; START = new Date(Date.now() - 1000).toISOString();
      if(!document.getElementById('kgv-css')){ const st = document.createElement('style'); st.id = 'kgv-css'; st.textContent = css; document.head.appendChild(st); }
      const { data: { session } } = await O.sb.auth.getSession(); ME = session?.user?.id || null;
      const { data: bn } = await O.sb.from('benutzer').select('id,anzeigename,email,rolle'); (bn || []).forEach(b => { NAMEN[b.id] = b.anzeigename || (b.email || '').split('@')[0]; if(b.id === ME) ADMIN = b.rolle === 'admin'; });
      let n = 0; const warte = () => { if(!einbauen() && n++ < 40) setTimeout(warte, 250); }; warte();
      let t = null; const spaeter = () => { clearTimeout(t); t = setTimeout(eigeneLaden, 1200); };
      ['pointerup', 'keyup', 'change', 'drop'].forEach(ev => addEventListener(ev, e => { if(el && el.contains(e.target)) return; spaeter(); }, true));
      document.addEventListener('visibilitychange', () => { if(!document.hidden) spaeter(); });
      addEventListener('keydown', e => {
        if(!(e.ctrlKey || e.metaKey) || e.altKey) return;
        const z = e.target, edit = z && (z.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(z.tagName));
        if(edit) return; const k = e.key.toLowerCase();
        if(k === 'z' && !e.shiftKey){ e.preventDefault(); zurueck(); } else if(k === 'y' || (k === 'z' && e.shiftKey)){ e.preventDefault(); vor(); }
      });
      await eigeneLaden();
    },
    // Tool meldet: andere Offerte geöffnet usw.
    async neu(){ ST = {}; REDO = []; schritte = []; grenze = 0; START = new Date(Date.now() - 1000).toISOString(); sel = null; await eigeneLaden(); if(offen) await listeLaden(); },
    aktualisieren: () => eigeneLaden(),
    offen: () => offen
  };
})();
