/* kg-kundenordner.js – Kundenordner im Google Drive (geteilte Ablage «01_Kundendaten / Projekte»)
   Einbinden nach supabase-js und kg-doku.js:  <script src="/kg-doku.js?v=1"></script><script src="/kg-kundenordner.js?v=1"></script>
   - Verknüpfung über die Ordner-ID pro Kunde und Jahr (Tabelle kunde_ordner), Namen spielen keine Rolle
   - neuer Jahresordner = Ordnerstruktur eines vorbereiteten Kundenordners aus «Vorlage 01-99» (nur Ordner, keine Dateien)
   - Google-Zugang wie in den Doku-Tools (KGD.googleToken / KGD.googleVerbinden, Refresh-Token serverseitig)
   KKO.init(sb) einmal aufrufen. */
(function(){
  const ROOT = '0AEZm9ALFx3sgUk9PVA', VORLAGE = '12hH-QP2_RZ559nmmxG_ZsKCrazUh6pon', ORDNER = 'application/vnd.google-apps.folder';
  const ortOhnePlz = o => String(o || '').replace(/^\d{4}\s*/, '').trim();
  const kinder = async (id, nurOrdner) => { const out = []; let token = '';
    do { const p = new URLSearchParams({ q: `'${id}' in parents and trashed=false${nurOrdner ? ` and mimeType='${ORDNER}'` : ''}`, corpora: 'drive', driveId: ROOT,
        includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: 'nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink,iconLink)', pageSize: '200', orderBy: 'folder,name' });
      if(token) p.set('pageToken', token);
      const d = await KGD.gapi('files?' + p); out.push(...(d.files || [])); token = d.nextPageToken || ''; } while(token);
    return out; };
  const ordnerNeu = (name, parent) => KGD.gapi('files?supportsAllDrives=true&fields=id,name,webViewLink', { method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, mimeType: ORDNER, parents: [parent] }) });
  let vorlageId = null;

  window.KKO = {
    sb: null,
    init(sb){ KKO.sb = sb; if(window.KGD) KGD.sb = sb; },
    link: id => 'https://drive.google.com/drive/folders/' + id,
    // Google: verbunden? (ohne Popup) / verbinden (muss aus einem Klick kommen)
    async verbunden(){ try { return !!(await KGD.googleToken()); } catch(e){ return false; } },
    async verbinden(){ await KGD.gsiLaden(); return KGD.googleVerbinden(); },
    vorladen(){ KGD.gsiLaden().catch(() => {}); },
    // verknüpfte Ordner eines Kunden (neueste zuerst, Stammordner oben)
    async liste(kundeId){ const { data, error } = await KKO.sb.from('kunde_ordner').select('*').eq('kunde_id', kundeId).order('jahr', { ascending: false, nullsFirst: true }); if(error) throw error; return data || []; },
    async verknuepfen(kundeId, o){ const { data, error } = await KKO.sb.from('kunde_ordner').upsert({ kunde_id: kundeId, jahr: o.jahr ? +o.jahr : null, drive_id: o.id, name: o.name }, { onConflict: 'kunde_id,drive_id' }).select().single(); if(error) throw error; return data; },
    async loesen(id){ const { error } = await KKO.sb.from('kunde_ordner').delete().eq('id', id); if(error) throw error; },
    // Vorschläge aus den Jahresordnern (Name, Ort, Strasse) – nur Vorschläge, bestätigen muss man selbst
    // Ortsname im Kundennamen («Aarekies Brienz AG») zählt nicht als Name; nur Ordner, bei denen der Name passt
    async vorschlaege(k){ const ort = ortOhnePlz(k.ort).toLowerCase(), name = String(k.nachname || k.firma || k.name || '').split(/\s+/).filter(w => !ort || w.toLowerCase() !== ort).join(' ');
      return (await KGD.ordnerVorschlag({ kunde_name: name, ort: k.ort, strasse: k.strasse })).filter(v => v.gruende.includes('Name passt')); },
    async ausLink(text){ const o = await KGD.ordnerAusLink(text); const f = await KGD.gapi(`files/${o.id}?supportsAllDrives=true&fields=id,name,parents`);
      let jahr = null; if(f.parents && f.parents[0]){ try { const p = await KGD.gapi(`files/${f.parents[0]}?supportsAllDrives=true&fields=name`); if(/^\d{4}$/.test(p.name)) jahr = +p.name; } catch(e){} }
      return { id: f.id, name: f.name, jahr }; },
    // Jahresordner «2026» unter der Ablage (fehlt er: anlegen)
    async jahresOrdner(jahr){ const l = await kinder(ROOT, true); const j = l.find(f => f.name === String(jahr)); return j || ordnerNeu(String(jahr), ROOT); },
    // Muster = erster vorbereitete Kundenordner (nur die Ordnerstruktur wird übernommen, keine Dateien) in der Vorlage («ZZZZZ-…»), sonst die Vorlage selbst
    async vorlage(){ if(vorlageId) return vorlageId; const l = await kinder(VORLAGE, true); const z = l.find(f => /^zzzz/i.test(f.name)); return (vorlageId = z ? z.id : VORLAGE); },
    // Ordnerstruktur der Vorlage einmal lesen (Ebenen gleichzeitig), einen Tag im Browser gemerkt
    async baum(quelleId){
      const key = 'kko-baum-' + quelleId;
      try { const m = JSON.parse(localStorage.getItem(key) || 'null'); if(m && Date.now() - m.zeit < 864e5) return m.baum; } catch(_){}
      const lesen = async id => Promise.all((await kinder(id, true)).map(async c => ({ name: c.name, kinder: await lesen(c.id) })));
      const baum = await lesen(quelleId);
      try { localStorage.setItem(key, JSON.stringify({ zeit: Date.now(), baum })); } catch(_){}
      return baum;
    },
    // Kundenordner aus der Vorlage: nur Unterordner, keine Dateien (Entscheid 2026-11-05); alle Ordner einer Ebene gleichzeitig anlegen
    async kopieren(quelleId, zielParent, name){
      const [neu, baum] = await Promise.all([ordnerNeu(name, zielParent), KKO.baum(quelleId)]);
      const anlegen = (knoten, parent) => Promise.all(knoten.map(async k => { const o = await ordnerNeu(k.name, parent); await anlegen(k.kinder, o.id); }));
      await anlegen(baum, neu.id);
      return neu;
    },
    // Kundenordner für ein Jahr anlegen (aus der Vorlage) und verknüpfen. Name «Meier Thun», gibt es ihn schon: «Meier Thun (Seestrasse)»
    async anlegen(k, jahr = new Date().getFullYear()){
      const jo = await KKO.jahresOrdner(jahr), da = new Set((await kinder(jo.id, true)).map(f => f.name.toLowerCase()));
      const basis = [k.nachname || k.firma || k.name, ortOhnePlz(k.ort)].filter(Boolean).join(' ').trim() || 'Kunde';
      let name = basis; if(da.has(name.toLowerCase())) name = `${basis} (${String(k.strasse || k.kundennummer || 'neu').replace(/\s*\d.*$/, '') || 'neu'})`;
      let n = 2; while(da.has(name.toLowerCase())) name = `${basis} (${n++})`;
      const neu = await KKO.kopieren(await KKO.vorlage(), jo.id, name);
      return KKO.verknuepfen(k.id, { id: neu.id, name, jahr });
    },
    // Ordner des aktuellen Jahres (fehlt er: aus der Vorlage anlegen)
    async aktuell(k){ const j = new Date().getFullYear(), l = await KKO.liste(k.id); return l.find(o => o.jahr === j) || KKO.anlegen(k, j); },
    // Dateien hochladen: Fotos in «20-Fotos Situation», alles andere in «06-Notizen» (fehlt der Unterordner: in den Kundenordner)
    async hochladen(k, files){
      const o = await KKO.aktuell(k), unter = await kinder(o.drive_id, true), erg = [];
      for(const f of files){
        const u = unter.find(x => (/^image\//.test(f.type) ? /^20\b/ : /^06\b/).test(x.name)), ziel = u ? u.id : o.drive_id;
        const form = new FormData();
        form.append('metadata', new Blob([JSON.stringify({ name: f.name, parents: [ziel] })], { type: 'application/json' }));
        form.append('file', f);
        erg.push(await KGD.gapi('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink', { method: 'POST', body: form }));
      }
      return { ordner: o, dateien: erg };
    },
    async dateien(ordnerId){ return kinder(ordnerId, false); },
    ROOT, async unterordner(id){ return kinder(id, true); },
    ablage: o => ablageFenster(o)
  };

  // ---------------------------------------------------------------------------
  // Ablage-Fenster: alle verknüpften Ordner eines Kunden über alle Jahre. Gleich benannte Unterordner
  // («22-Fotos-Bauablauf und Schluss» in 2024, 2025 …) werden zusammengefasst; Fotos als Bildraster, Suche über alles.
  // ---------------------------------------------------------------------------
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  const ohneNr = n => String(n || '').replace(/^\d+\s*[-_.]\s*/, '').trim();
  const schluessel = n => ohneNr(n).toLowerCase().replace(/[\s_-]+/g, ' ');
  const istBild = f => /^image\//.test(f.mimeType);
  const datum = v => v ? new Date(v).toLocaleDateString('de-CH') : '';
  // alle Dateien unter einem Ordner (bis 4 Ebenen), mit Pfad; Unterordner der ersten Ebene = Gruppe
  async function einlesen(ordner, jahr){
    const out = [], felder = 'nextPageToken,files(id,name,mimeType,modifiedTime,webViewLink,iconLink,thumbnailLink,size)';
    const lesen = async (id, pfad, tiefe) => { let token = '', alle = [];
      do { const p = new URLSearchParams({ q: `'${id}' in parents and trashed=false`, corpora: 'drive', driveId: ROOT, includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: felder, pageSize: '1000' });
        if(token) p.set('pageToken', token); const d = await KGD.gapi('files?' + p); alle.push(...(d.files || [])); token = d.nextPageToken || ''; } while(token);
      await Promise.all(alle.map(f => f.mimeType === ORDNER ? (tiefe < 4 ? lesen(f.id, [...pfad, f.name], tiefe + 1) : null) : out.push({ ...f, jahr, pfad, gruppe: pfad[0] || '' })));
      if(!pfad.length) alle.filter(f => f.mimeType === ORDNER).forEach(f => out.push({ ordner: true, id: f.id, name: f.name, jahr, gruppe: f.name, pfad: [] }));
    };
    await lesen(ordner, [], 1);
    return out;
  }
  const ORD_ICON = {
    lupe: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#8b9097" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4.5 4.5"/></svg>',
    mic: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><rect x="9" y="3.5" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/></svg>',
    ordner: g => `<svg width="${g}" height="${g}" viewBox="0 0 24 24" fill="${g > 15 ? '#5f6873' : '#9aa2ab'}" aria-hidden="true"><path d="M3 6.5A1.5 1.5 0 0 1 4.5 5h4.6l2 2h8.4A1.5 1.5 0 0 1 21 8.5v9A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5z"/></svg>`,
    alle: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" aria-hidden="true"><rect x="4" y="4" width="16" height="16" rx="2.5"/><path d="M4 9h16M9 9v11"/></svg>',
    pfeil: '<svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" aria-hidden="true"><path d="M9 6l6 6-6 6"/></svg>' };
  const CSS = `
.kab-ovl{position:fixed;inset:0;z-index:300;background:rgba(35,43,53,.45);display:flex;align-items:center;justify-content:center;padding:16px}
.kab-fen{width:min(1240px,100%);height:min(820px,100%);background:#fff;border-radius:14px;overflow:hidden;display:flex;box-shadow:0 20px 60px rgba(0,0,0,.3);position:relative}
.kab-menu{width:300px;flex:none;overflow:auto;padding:14px;display:flex;flex-direction:column;gap:3px;border-right:1px solid #e1e5e9;font-size:13px}
.kab-menu .t b{color:#323e4e;font-size:14px;display:block}.kab-menu .t small{color:#6b7079;font-size:11.5px}
.kab-such{display:flex;align-items:center;gap:6px;border:1.5px solid #323e4e;border-radius:12px;padding:0 5px 0 11px;height:44px;margin:12px 0 10px;flex:none}
.kab-such input{all:unset;flex:1;min-width:0;font-size:14px;color:#232b35}
.kab-mic{all:unset;cursor:pointer;width:34px;height:34px;border-radius:50%;background:#d6e7f4;color:#323e4e;display:flex;align-items:center;justify-content:center;flex:none}
.kab-mic.an{background:#323e4e;color:#fff}
.kg-seg.kab-jahre{display:flex!important;width:100%!important;margin:0 0 10px!important;flex:none}.kg-seg.kab-jahre>button{flex:1;justify-content:center;padding:0 4px}
.kab-g{all:unset;box-sizing:border-box;cursor:pointer;display:flex;align-items:center;gap:10px;padding:7px 10px;border-radius:8px;color:#232b35;font-size:13.5px}
.kab-g span{flex:1;min-width:0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.kab-g svg{flex:none}
.kab-g:hover{background:#f5f7f9}.kab-g[aria-pressed=true]{background:#d6e7f4;font-weight:600}
.kab-g small{color:#8b9097;font-size:11.5px;font-weight:400}.kab-g.leer{opacity:.45}
.kab-g.klein{font-size:12px;padding:4px 10px;gap:8px}
.kab-trenn{height:1px;background:#eef1f4;margin:4px 6px;flex:none}
.kab-mehr{all:unset;cursor:pointer;font-size:11px;font-weight:700;letter-spacing:.04em;text-transform:uppercase;color:#8b9097;padding:12px 8px 4px;display:flex;gap:6px;align-items:center}
.kab-mehr svg{transition:transform .15s}.kab-mehr[aria-expanded=true] svg{transform:rotate(90deg)}
.kab-rechts{flex:1;min-width:0;display:flex;flex-direction:column}
.kab-kopf{display:flex;gap:8px;align-items:center;padding:10px 54px 10px 14px;border-bottom:1px solid #e1e5e9;flex-wrap:wrap}
.kab-kopf h3{margin:0;font-size:15px;color:#323e4e;flex:1;min-width:0}
.kab-inhalt{flex:1;overflow:auto;padding:12px 14px}
.kab-jahr{font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:#6b7079;font-weight:700;margin:12px 0 6px}
.kab-raster{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:8px}
.kab-bild{all:unset;cursor:pointer;position:relative;aspect-ratio:4/3;border-radius:8px;overflow:hidden;background:#eef1f4}
.kab-bild img{width:100%;height:100%;object-fit:cover;display:block}
.kab-bild span{position:absolute;left:0;right:0;bottom:0;font-size:10.5px;color:#fff;background:linear-gradient(transparent,rgba(0,0,0,.6));padding:10px 6px 4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.kab-liste{display:flex;flex-direction:column}
.kab-z{display:grid;grid-template-columns:20px minmax(0,1fr) auto auto;gap:10px;align-items:center;padding:7px 4px;border-bottom:1px solid #eef1f4;font-size:13px;color:#232b35;text-decoration:none}
.kab-z:hover{background:#f8fafc}.kab-z small{color:#6b7079;font-size:11.5px}.kab-z img{width:16px;height:16px}
.kab-leer{color:#6b7079;font-size:13px;padding:20px 0}
.kab-zu{position:absolute;top:10px;right:10px;z-index:5;width:30px;height:30px}
.kab-gross{position:absolute;inset:0;z-index:10;background:rgba(15,20,26,.92);display:flex;align-items:center;justify-content:center}
.kab-gross img{max-width:calc(100% - 120px);max-height:calc(100% - 70px);object-fit:contain}
.kab-gross .n{position:absolute;bottom:14px;left:0;right:0;text-align:center;color:#fff;font-size:12.5px}
.kab-gross button.p{all:unset;cursor:pointer;position:absolute;top:50%;margin-top:-24px;width:48px;height:48px;border-radius:50%;background:rgba(255,255,255,.15);color:#fff;font-size:28px;line-height:46px;text-align:center}
.kab-gross button.p:hover{background:rgba(255,255,255,.3)}
.kab-gross a{position:absolute;top:14px;left:14px;color:#fff;font-size:12.5px;font-weight:600}
@media (max-width:760px){.kab-fen{flex-direction:column}.kab-menu{width:auto;max-height:40%;border-right:0;border-bottom:1px solid #e1e5e9}}`;
  async function ablageFenster({ kunde, ordner, titel, untertitel }){
    if(!document.getElementById('kab-css')){ const s = document.createElement('style'); s.id = 'kab-css'; s.textContent = CSS; document.head.appendChild(s); }
    const h = document.createElement('div'); h.className = 'kab-ovl';
    const x = window.KG && KG.icon ? KG.icon('x', 14) : '×';
    h.innerHTML = `<div class="kab-fen" role="dialog" aria-label="Ablage"><aside class="kab-menu"><div class="t"><b>${esc(titel || 'Ablage')}</b><small>${esc(untertitel || '')}</small></div>
      <label class="kab-such">${ORD_ICON.lupe}<input type="search" placeholder="Was suchst du? z. B. Lieferschein Platten" aria-label="Suchen in Namen und Inhalt aller Dateien" data-q autocomplete="off" data-lpignore="true" data-1p-ignore="true" data-dashlane-ignore="true" data-form-type="other">
        <button type="button" class="kab-mic" data-mic aria-label="Spracheingabe" title="Spracheingabe" hidden>${ORD_ICON.mic}</button></label>
      <div class="kg-seg kab-jahre" role="group" aria-label="Jahr" data-jahre></div>
      <div data-gruppen><span class="kab-leer">Ordner werden gelesen …</span></div></aside>
      <section class="kab-rechts"><div class="kab-kopf"><h3 data-titel>Alle Dateien</h3>
        <label class="btn btn-ghost btn-sm" style="display:none;cursor:pointer;align-items:center;gap:6px" data-hoch>${window.KG && KG.icon ? KG.icon('upload', 13) : ''}<span>Hochladen</span><input type="file" multiple hidden></label></div>
        <div class="kab-inhalt" data-inhalt></div></section>
      <button type="button" class="kg-ibtn kab-zu" data-zu aria-label="Schliessen" title="Schliessen (Esc)">${x}</button></div>`;
    document.body.appendChild(h);
    const $ = s => h.querySelector(s);
    let ALLE = [], GRUPPE = '', Q = '', BILDER = [], gross = -1, JAHRE = new Set(), WEITERE = false, VOLL = null;
    const jahrOk = f => !JAHRE.size || JAHRE.has(String(f.jahr));
    const zu = () => { document.removeEventListener('keydown', taste, true); h.remove(); };
    const taste = e => { if(e.key === 'Escape'){ e.stopPropagation(); if(gross >= 0) grossZu(); else zu(); }
      if(gross >= 0 && e.key === 'ArrowRight') grossZeigen(gross + 1); if(gross >= 0 && e.key === 'ArrowLeft') grossZeigen(gross - 1); };
    document.addEventListener('keydown', taste, true);
    h.addEventListener('mousedown', e => { if(e.target === h) zu(); });
    $('[data-zu]').onclick = zu;
    try {
      const teile = await Promise.all(ordner.map(o => einlesen(o.drive_id, o.jahr || 'Stamm')));
      ALLE = teile.flat();
    } catch(err){ $('[data-gruppen]').innerHTML = `<span class="kab-leer">${esc(err.message)}</span>`; return; }
    const gruppen = () => { const m = new Map();
      ALLE.forEach(f => { const k = f.gruppe ? schluessel(f.gruppe) : '_'; const g = m.get(k) || { k, name: f.gruppe ? ohneNr(f.gruppe) : 'Direkt im Kundenordner', n: 0, ges: 0, da: new Set() };
        g.da.add(String(f.jahr)); if(!f.ordner){ g.ges++; if(jahrOk(f)) g.n++; } m.set(k, g); });
      // zuoberst die Ordner, die es in den meisten Jahren gibt, dann nach Anzahl Dateien
      return [...m.values()].filter(g => g.ges || g.k !== '_').sort((a, b) => b.da.size - a.da.size || b.ges - a.ges || a.name.localeCompare(b.name, 'de')); };
    const alleJahre = () => [...new Set(ALLE.map(f => String(f.jahr)))].sort((a, b) => (a === 'Stamm') - (b === 'Stamm') || b.localeCompare(a));
    const passt = f => { if(f.ordner || !jahrOk(f)) return false; if(GRUPPE && (f.gruppe ? schluessel(f.gruppe) : '_') !== GRUPPE) return false;
      if(!Q) return true; if(VOLL && VOLL.has(f.id)) return true; const t = [f.name, ...(f.pfad || [])].join(' ').toLowerCase(); return Q.split(/\s+/).every(w => t.includes(w)); };
    const zeichneGruppen = () => { const gs = gruppen(), js = alleJahre(), total = ALLE.filter(f => !f.ordner && jahrOk(f)).length;
      // Jahre: «Alle» oder ein bis mehrere Jahre zusammen
      $('[data-jahre]').innerHTML = `<button type="button" data-jahr="" class="${JAHRE.size ? '' : 'on'}">Alle</button>` + js.map(j => `<button type="button" data-jahr="${esc(j)}" class="${JAHRE.has(j) ? 'on' : ''}">${esc(j === 'Stamm' ? 'Stamm' : j)}</button>`).join('');
      // Hauptordner = in mindestens zwei Jahren vorhanden; Einzelstücke klein unter «Weitere Ordner»
      const viele = js.length > 1, haupt = gs.filter(g => !viele || g.da.size > 1), weitere = viele ? gs.filter(g => g.da.size <= 1) : [];
      const zeile = (g, klein) => `<button type="button" class="kab-g${klein ? ' klein' : ''}${g.n ? '' : ' leer'}" data-g="${esc(g.k)}" aria-pressed="${GRUPPE === g.k}">${ORD_ICON.ordner(klein ? 14 : 18)}<span>${esc(g.name)}</span><small>${g.n || '–'}</small></button>`;
      $('[data-gruppen]').innerHTML = `<button type="button" class="kab-g" data-g="" aria-pressed="${!GRUPPE}">${ORD_ICON.alle}<span>Alle Dateien</span><small>${total}</small></button><div class="kab-trenn"></div>`
        + haupt.map(g => zeile(g, false)).join('')
        + (weitere.length ? `<button type="button" class="kab-mehr" data-mehr aria-expanded="${WEITERE}">${ORD_ICON.pfeil}Weitere Ordner (${weitere.length})</button>` + (WEITERE ? weitere.map(g => zeile(g, true)).join('') : '') : ''); };
    const zeichneInhalt = () => {
      const l = ALLE.filter(passt).sort((a, b) => String(b.jahr).localeCompare(String(a.jahr)) || String(b.modifiedTime).localeCompare(String(a.modifiedTime)));
      const g = gruppen().find(x => x.k === GRUPPE); $('[data-titel]').textContent = (g ? g.name : 'Alle Dateien') + (JAHRE.size ? ' · ' + [...JAHRE].sort().reverse().join(', ') : '') + (Q ? ` · Suche «${Q}»` : '') + ` · ${l.length}`;
      $('[data-hoch]').style.display = GRUPPE && GRUPPE !== '_' ? 'inline-flex' : 'none';
      BILDER = l.filter(istBild);
      if(!l.length){ $('[data-inhalt]').innerHTML = '<div class="kab-leer">Keine Dateien.</div>'; return; }
      const jahre = [...new Set(l.map(f => f.jahr))];
      $('[data-inhalt]').innerHTML = jahre.map(j => { const bi = l.filter(f => f.jahr === j && istBild(f)), an = l.filter(f => f.jahr === j && !istBild(f));
        return `<div class="kab-jahr">${esc(j)}</div>${bi.length ? `<div class="kab-raster">${bi.map(f => `<button type="button" class="kab-bild" data-b="${BILDER.indexOf(f)}" title="${esc([...(f.pfad || []), f.name].join(' / '))}"><img loading="lazy" alt="" data-id="${f.id}" src="${esc((f.thumbnailLink || '').replace(/=s\d+$/, '=s400'))}"><span>${esc(f.name)}</span></button>`).join('')}</div>` : ''}
          ${an.length ? `<div class="kab-liste">${an.map(f => `<a class="kab-z" href="${esc(f.webViewLink)}" target="_blank" rel="noopener"><img src="${esc(f.iconLink)}" alt=""><span>${esc(f.name)}<br><small>${esc((f.pfad || []).map(ohneNr).join(' / '))}</small></span><small>${datum(f.modifiedTime)}</small><small>öffnen</small></a>`).join('')}</div>` : ''}`; }).join('');
      // Vorschaubild nicht erreichbar (abgelaufen): über die Drive-Schnittstelle nachladen
      $('[data-inhalt]').querySelectorAll('img[data-id]').forEach(im => im.onerror = async () => { im.onerror = null; try { im.src = await bildUrl(im.dataset.id); } catch(_){} });
    };
    const blobs = {};
    const bildUrl = async id => { if(blobs[id]) return blobs[id]; const t = await KGD.googleToken();
      const r = await fetch(`https://www.googleapis.com/drive/v3/files/${id}?alt=media&supportsAllDrives=true`, { headers: { Authorization: 'Bearer ' + t } });
      if(!r.ok) throw new Error('Bild nicht ladbar'); return (blobs[id] = URL.createObjectURL(await r.blob())); };
    const grossZu = () => { gross = -1; h.querySelector('.kab-gross')?.remove(); };
    const grossZeigen = async i => { if(!BILDER.length) return; gross = (i + BILDER.length) % BILDER.length; const f = BILDER[gross];
      let g = h.querySelector('.kab-gross'); if(!g){ g = document.createElement('div'); g.className = 'kab-gross'; h.querySelector('.kab-fen').appendChild(g);
        g.addEventListener('click', e => { if(e.target === g) grossZu(); }); }
      g.innerHTML = `<a href="${esc(f.webViewLink)}" target="_blank" rel="noopener">Im Drive öffnen</a><button type="button" class="p" style="left:14px" data-p="-1" aria-label="Vorheriges">‹</button>
        <img alt="" src="${esc((f.thumbnailLink || '').replace(/=s\d+$/, '=s1600'))}"><button type="button" class="p" style="right:14px" data-p="1" aria-label="Nächstes">›</button>
        <div class="n">${esc(f.name)} · ${esc(f.jahr)} · ${gross + 1} / ${BILDER.length}</div>
        <button type="button" class="kg-ibtn kab-zu" data-gzu aria-label="Schliessen">${x}</button>`;
      g.querySelectorAll('[data-p]').forEach(b => b.onclick = () => grossZeigen(gross + +b.dataset.p)); g.querySelector('[data-gzu]').onclick = grossZu;
      const im = g.querySelector('img'), id = f.id; im.onerror = async () => { im.onerror = null; try { const u = await bildUrl(id); if(BILDER[gross]?.id === id) im.src = u; } catch(_){} }; };
    h.addEventListener('click', e => { const b = e.target.closest('[data-g]'); if(b){ GRUPPE = b.dataset.g; zeichneGruppen(); zeichneInhalt(); return; }
      const jb = e.target.closest('[data-jahr]'); if(jb){ const j = jb.dataset.jahr; if(!j) JAHRE.clear(); else if(JAHRE.has(j)) JAHRE.delete(j); else JAHRE.add(j);
        if(JAHRE.size === alleJahre().length) JAHRE.clear(); zeichneGruppen(); zeichneInhalt(); return; }
      if(e.target.closest('[data-mehr]')){ WEITERE = !WEITERE; zeichneGruppen(); return; }
      const bi = e.target.closest('[data-b]'); if(bi) grossZeigen(+bi.dataset.b); });
    let qT = null, vT = null, vNr = 0;
    const vollSuche = async q => { const nr = ++vNr; const w = q.split(/\s+/).filter(x => x.length > 1); if(!w.length || q.length < 3){ VOLL = null; return; }
      const p = new URLSearchParams({ q: w.map(x => `fullText contains '${x.replace(/['\\]/g, '\\$&')}'`).join(' and ') + ' and trashed=false', corpora: 'drive', driveId: ROOT,
        includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: 'files(id)', pageSize: '1000' });
      try { const d = await KGD.gapi('files?' + p); if(nr === vNr){ VOLL = new Set((d.files || []).map(f => f.id)); zeichneInhalt(); } } catch(_){} };
    const suchen = v => { clearTimeout(qT); clearTimeout(vT); qT = setTimeout(() => { Q = v.trim().toLowerCase(); VOLL = null; zeichneInhalt(); vT = setTimeout(() => vollSuche(Q), 450); }, 150); };
    $('[data-q]').oninput = e => suchen(e.target.value);
    const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if(SR){ const mic = $('[data-mic]'); mic.hidden = false; let rec = null;
      mic.onclick = () => { if(rec){ rec.stop(); return; } rec = new SR(); rec.lang = 'de-CH'; rec.interimResults = true; mic.classList.add('an');
        rec.onresult = ev => { const t = [...ev.results].map(r => r[0].transcript).join(' '); $('[data-q]').value = t; suchen(t); };
        rec.onend = rec.onerror = () => { rec = null; mic.classList.remove('an'); }; rec.start(); }; }
    // Hochladen in die gewählte Gruppe im Ordner des aktuellen Jahres (fehlt er: aus der Vorlage anlegen)
    $('[data-hoch] input').onchange = async e => { const files = [...e.target.files]; if(!files.length || !kunde) return; const lab = $('[data-hoch] span'), alt = lab.textContent;
      try { lab.textContent = 'Lädt hoch …'; const o = await KKO.aktuell(kunde), unter = await kinder(o.drive_id, true), u = unter.find(y => schluessel(y.name) === GRUPPE), ziel = u ? u.id : o.drive_id;
        for(const [i, f] of files.entries()){ lab.textContent = `Lädt ${i + 1}/${files.length} …`; const form = new FormData();
          form.append('metadata', new Blob([JSON.stringify({ name: f.name, parents: [ziel] })], { type: 'application/json' })); form.append('file', f);
          const d = await KGD.gapi('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,mimeType,modifiedTime,webViewLink,iconLink,thumbnailLink', { method: 'POST', body: form });
          ALLE.push({ ...d, jahr: o.jahr || new Date().getFullYear(), pfad: u ? [u.name] : [], gruppe: u ? u.name : '' }); }
        zeichneGruppen(); zeichneInhalt();
      } catch(err){ alert('Hochladen: ' + err.message); } finally { lab.textContent = alt; e.target.value = ''; } };
    zeichneGruppen(); zeichneInhalt(); $('[data-q]').focus();
  }
})();
