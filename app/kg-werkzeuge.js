/* kg-werkzeuge.js – gemeinsame Teile des Tools «Werkzeuge» (Rechner & Hilfsmittel).
   Einbinden nach supabase-js:  <script src="/kg-werkzeuge.js?v=1"></script>
   - KGW.KATEGORIEN / KGW.LISTE: alle Kategorien und Werkzeuge (auch für das Widget auf der Startseite)
   - KGW.start(fertig): Login, Rechte, Favoriten laden, danach fertig(main)
   - KGW.werkzeug(key, aufbau): Rahmen einer Werkzeug-Seite (Zurück, Titel, Stern) + aufbau(inhalt)
   - Bausteine: KGW.karte, KGW.feld (− Zahl +), KGW.seg, KGW.zahl, KGW.fmt
   Rechte: kg-stil.js (SEITENRECHT) sperrt die Seiten; Schalter pro Werkzeug in kg-rechte.js. */
(function(){
  const PAL = (window.KG && KG.palette) || {};
  const farbe = (fam, i, alt) => (PAL[fam] && PAL[fam][i]) || alt;
  const KATEGORIEN = [
    { k: 'pool', n: 'Pool', farbe: farbe('blau', 1, '#2F5C9A'),
      d: '<path d="M2 16c2 0 2-1.5 4-1.5s2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5M2 20c2 0 2-1.5 4-1.5s2 1.5 4 1.5 2-1.5 4-1.5 2 1.5 4 1.5 2-1.5 4-1.5"/><path d="M8 13V5a2 2 0 0 1 4 0M16 13V5a2 2 0 0 0-4 0M8 8h8"/>' },
    { k: 'bau', n: 'Bau', farbe: farbe('erde', 1, '#6E4C35'), d: '<path d="M3 6h18v12H3zM3 12h18M9 6v6M15 12v6"/>' },
    { k: 'pflege', n: 'Pflege', farbe: farbe('gruen', 1, '#3F7D3F'), d: '<path d="M5 19c0-8 5-13 14-14 0 9-5 14-13 14z"/><path d="M5 19l8-8"/>' },
    { k: 'buero', n: 'Büro', farbe: farbe('violett', 1, '#5C3F94'), d: '<path d="M14 3H7a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8z"/><path d="M14 3v5h5M9 13h6M9 17h4"/>' }
  ];
  const W = (k, kat, n, h) => ({ k, kat, n, h, seite: 'werkzeug-' + k.replace('_', '-') + '-live-v1' });
  const LISTE = [
    W('pool_chlor', 'pool', 'Stosschlorung', 'Chlorifix nach Volumen'),
    W('pool_salz', 'pool', 'Salzzugabe', 'NaCl & MgCl₂ nach TDS'),
    W('pool_alk', 'pool', 'Alkalinität', 'Alca Plus dosieren'),
    W('pool_afm', 'pool', 'AFM Filterbefüllung', 'Säcke pro Apollo-Filter'),
    W('pool_volumen', 'pool', 'Pool-Volumen', 'Rechteck, rund, oval, Freiform'),
    W('bau_diagonale', 'bau', 'Rechter Winkel', 'Diagonale aus zwei Seiten'),
    W('bau_kies', 'bau', 'Kies-Gewicht', 'm³ in Tonnen, nach Kiessorte'),
    W('bau_stahl', 'bau', 'Stahl', 'Gewicht von Gefäss, Blech, Rohr, Winkel'),
    W('bau_schalit', 'bau', 'Beton für Schalungssteine', 'SCHALIT: Füllbeton, Steine, Paletten'),
    W('pflege_spritz', 'pflege', 'Spritzmittel', 'Wie viel Mittel in den Tank, mit Umrechner'),
    W('allg_gefaelle', 'bau', 'Gefälle', 'Prozent ↔ Höhe ↔ Länge')
  ];
  // Welche Kategorie beim Öffnen schon offen ist (recht_gruppe.schluessel); Hilfsarbeitende: alle zu
  // (eine leere Kategorie bleibt trotzdem zu, siehe werkzeuge-live-v1.html)
  const START_OFFEN = { pool: 'pool', va_pflege: 'pflege', va_bau: 'bau', buero: 'buero', admin: 'pool' };

  const $ = id => document.getElementById(id);
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const svg = (p, s = 18, extra = '') => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" ${extra}>${p}</svg>`;
  const pfad = n => (window.KG && KG.pfad && KG.pfad(n)) || '';
  const lsGet = (k, alt) => { try { const v = localStorage.getItem(k); return v === null ? alt : JSON.parse(v); } catch(e){ return alt; } };
  const lsSet = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch(e){} };
  const num = v => { const n = parseFloat(String(v ?? '').replace(',', '.').replace(/['’\s]/g, '')); return isFinite(n) ? n : 0; };
  const fmt = (x, d = 1) => (isFinite(x) ? x : 0).toLocaleString('de-CH', { minimumFractionDigits: d, maximumFractionDigits: d });

  const CSS = `
body{margin:0;background:#F5F7F9;color:#232B35;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Arial,sans-serif;font-size:14px;line-height:1.4;-webkit-tap-highlight-color:transparent;}
*{box-sizing:border-box;}
.hidden{display:none!important;}
header.app{background:#323E4E;color:#fff;}
header.app .wrap{display:flex;align-items:center;gap:16px;padding:0 16px;}
header.app .brand h1{font-size:15px;margin:0;}
.kgw{max-width:620px;margin:0 auto;padding:12px 12px calc(32px + env(safe-area-inset-bottom,0px));display:flex;flex-direction:column;gap:12px;}
.kgw-stapel{display:flex;flex-direction:column;gap:12px;}
.kgw-seg{--kg-tool:var(--kf,#4C5C70);}
.kgw-karte{background:#fff;border-radius:10px;box-shadow:0 1px 3px rgba(35,43,53,.08),0 0 0 1px rgba(35,43,53,.04);overflow:hidden;}
.kgw-kopf{height:34px;display:flex;align-items:center;gap:8px;padding:0 12px;background:var(--kf,#4C5C70);color:#fff;}
.kgw-kopf h2{margin:0;font-size:13px;font-weight:700;flex:1;}
.kgw-body{padding:12px;display:flex;flex-direction:column;gap:10px;}
.kgw-titel{display:flex;align-items:center;gap:4px;margin-top:-4px;}
.kgw-zurueck{display:inline-flex;align-items:center;gap:2px;min-height:44px;padding-right:6px;font-weight:600;font-size:13px;text-decoration:none;color:var(--kf,#4C5C70);}
.kgw-titel h1{margin:0;font-size:20px;font-weight:700;color:#323E4E;flex:1;min-width:0;}
.kgw-stern{all:unset;cursor:pointer;width:44px;height:44px;display:inline-flex;align-items:center;justify-content:center;flex:none;color:#A3B0BE;}
.kgw-stern[aria-pressed="true"] svg{fill:#D1DB5F;color:#7C8726;}
.kgw-feld{display:flex;align-items:center;gap:8px;}
.kgw-feld > label{flex:1;font-size:14px;color:#4C5C70;}
.kgw-pm{all:unset;cursor:pointer;width:44px;height:44px;border:1px solid #D5DBE1;border-radius:8px;background:#fff;display:inline-flex;align-items:center;justify-content:center;font-size:20px;color:#323E4E;flex:none;}
.kgw-pm:active{background:#F5F7F9;}
.kgw-zahl{width:84px;height:44px;border:1px solid #B9C0C8;border-radius:8px;text-align:center;font:inherit;font-size:17px;color:#232B35;background:#fff;}
.kgw-zahl:focus,.kgw-text:focus{outline:none;border-color:#323E4E;}
.kgw-text{height:40px;border:1px solid #B9C0C8;border-radius:8px;padding:0 10px;font:inherit;font-size:15px;width:100%;}
.kgw-seg{display:grid!important;grid-auto-flow:column;grid-auto-columns:minmax(0,1fr);height:42px!important;width:100%!important;}
.kgw-seg > button{justify-content:center;font-size:13px!important;}
.kgw-zeile{display:flex;justify-content:space-between;gap:10px;font-size:13.5px;color:#6B7079;}
.kgw-zeile b{color:#232B35;}
.kgw-trenn{border-top:1px solid #EEF1F4;padding-top:10px;}
/* Resultate rechtsbündig – gerechnet wird rechts */
.kgw-gross{display:flex;align-items:baseline;justify-content:flex-end;gap:6px;color:#323E4E;}
.kgw-gross ~ .kgw-klein{align-self:flex-end;text-align:right;}
.kgw-gross b{font-size:40px;line-height:1.05;font-weight:700;}
.kgw-gross span{font-size:18px;}
.kgw-klein{font-size:12px;color:#6B7079;}
.kgw-info{display:flex;gap:10px;padding:8px 0;border-bottom:1px solid #F1F3F5;font-size:13.5px;}
.kgw-info:last-child{border-bottom:0;}
.kgw-info b{width:62px;flex:none;color:var(--kf,#4C5C70);}
.kgw-schalter{display:flex;align-items:center;gap:10px;min-height:44px;font-size:14px;cursor:pointer;}
.kgw-schalter input{width:20px;height:20px;accent-color:#323E4E;}
.kgw-leer{font-size:13.5px;color:#6B7079;padding:12px 14px 14px;}
.kgw-hinweis{font-size:12.5px;color:#6B7079;}
.kgw-warn{font-size:13.5px;font-weight:600;color:#B4655F;}
.loginwrap{min-height:70vh;display:flex;align-items:center;justify-content:center;}
.logincard{background:#fff;border-radius:12px;box-shadow:0 1px 3px rgba(35,43,53,.08),0 0 0 1px rgba(35,43,53,.04);padding:24px 22px;width:100%;max-width:340px;display:flex;flex-direction:column;gap:10px;}
.logincard h2{font-size:17px;margin:0 0 4px;color:#323E4E;}
.logincard label{font-size:12px;color:#6B7079;}
.logincard input{height:44px;border:1px solid #B9C0C8;border-radius:8px;padding:0 10px;font:inherit;font-size:16px;width:100%;}
.logincard button{all:unset;box-sizing:border-box;cursor:pointer;height:44px;border-radius:8px;background:#323E4E;color:#fff;font-weight:600;text-align:center;}
.logincard .status{font-size:12.5px;color:#6B7079;min-height:16px;}
.logincard .status.err{color:#B4655F;}
.kgw-toast{position:fixed;left:50%;bottom:calc(20px + env(safe-area-inset-bottom,0px));transform:translateX(-50%);background:#323E4E;color:#fff;font-size:13px;padding:9px 14px;border-radius:8px;box-shadow:0 6px 20px rgba(0,0,0,.2);z-index:100;}
.kgw-toast.err{background:#B4655F;}
/* Startseite der Werkzeuge */
.kgw-favs{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;padding:10px 12px 12px;}
.kgw-fav{display:flex;align-items:center;gap:8px;min-height:48px;padding:6px 10px;border:1px solid #D5DBE1;border-radius:8px;text-decoration:none;color:#232B35;font-weight:600;font-size:13px;line-height:1.25;}
.kgw-fav:hover{border-color:#323E4E;}
.kgw-punkt{width:8px;height:8px;border-radius:2px;flex:none;}
.kgw-kat > button{all:unset;box-sizing:border-box;cursor:pointer;width:100%;display:flex;align-items:center;gap:12px;padding:0 14px;min-height:60px;}
.kgw-katicon{width:36px;height:36px;border-radius:9px;display:inline-flex;align-items:center;justify-content:center;flex:none;color:#fff;}
.kgw-katname{flex:1;display:flex;flex-direction:column;gap:1px;}
.kgw-katname b{font-size:17px;color:#323E4E;}
.kgw-katname small{font-size:12.5px;color:#6B7079;}
.kgw-kat .kgw-chev{color:#6E7F93;transition:transform .15s;}
.kgw-kat[data-offen="1"] .kgw-chev{transform:rotate(180deg);}
.kgw-liste{border-top:1px solid #EEF1F4;}
.kgw-z{display:flex;align-items:center;}
.kgw-z + .kgw-z{border-top:1px solid #EEF1F4;}
.kgw-z .kgw-stern{width:62px;height:52px;}
.kgw-z a{flex:1;display:flex;align-items:center;gap:12px;padding:7px 14px 7px 0;min-height:52px;text-decoration:none;color:#232B35;}
.kgw-z a span{flex:1;display:flex;flex-direction:column;gap:1px;}
.kgw-z a b{font-size:15px;}
.kgw-z a small{font-size:12.5px;color:#6B7079;}
.kgw-z a svg{color:#A3B0BE;}
`;

  const KGW = window.KGW = {
    KATEGORIEN, LISTE, START_OFFEN, num, fmt, esc, svg, lsGet, lsSet,
    kat: k => KATEGORIEN.find(x => x.k === k),
    sb: null, ich: null, gruppe: null, favs: new Set(),

    toast(text, err){
      const t = document.createElement('div'); t.className = 'kgw-toast' + (err ? ' err' : ''); t.textContent = text;
      document.body.appendChild(t); setTimeout(() => t.remove(), err ? 5000 : 1800);
    },

    // Login + Rechte + Favoriten; danach fertig(main)
    async start(fertig){
      if(!document.getElementById('kgw-css')){ const st = document.createElement('style'); st.id = 'kgw-css'; st.textContent = CSS; document.head.appendChild(st); }
      KG._sb = KG._sb || window.supabase.createClient('https://oalapdxinqlnzwxhyuzy.supabase.co', 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P');
      const sb = KGW.sb = KG._sb, main = $('appMain');
      const lo = $('logoutBtn'); if(lo) lo.addEventListener('click', async () => { await sb.auth.signOut(); location.reload(); });
      const { data: { session } } = await sb.auth.getSession();
      if(!session){ KGW.login(main, fertig); return; }
      const { data: b } = await sb.from('benutzer').select('rolle,aktiv,email,anzeigename,recht_gruppe_id').eq('id', session.user.id).maybeSingle();
      if(!b || !b.rolle || b.aktiv === false){ main.innerHTML = '<div class="loginwrap"><div class="logincard"><h2>Noch nicht freigeschaltet</h2><p class="kgw-hinweis">Dein Konto wartet auf Freischaltung durch einen Admin.</p></div></div>'; return; }
      KGW.ich = session.user.id;
      const [gr, fav] = await Promise.all([
        b.recht_gruppe_id ? sb.from('recht_gruppe').select('schluessel').eq('id', b.recht_gruppe_id).maybeSingle() : Promise.resolve({ data: null }),
        sb.from('werkzeug_favorit').select('werkzeug_key,sortierung,erstellt_am').order('sortierung').order('erstellt_am'),
        KG.ladeRechte ? KG.ladeRechte() : null
      ]);
      KGW.gruppe = (gr.data && gr.data.schluessel) || (b.rolle === 'admin' ? 'admin' : b.rolle === 'buero_team' ? 'buero' : null);
      KGW.favs = new Set((fav.data || []).map(f => f.werkzeug_key));
      const ub = $('userbar'); if(ub){ ub.classList.remove('hidden'); const t = $('userbarText'); if(t) t.textContent = b.anzeigename || b.email || ''; }
      fertig(main);
    },

    login(main, fertig){
      main.innerHTML = `<div class="loginwrap"><div class="logincard"><h2>Anmelden</h2>
        <label for="loginEmail">E-Mail</label><input autocomplete="username" id="loginEmail" type="email">
        <label for="loginPassword">Passwort</label><input autocomplete="current-password" id="loginPassword" type="password">
        <button type="button" id="loginBtn">Anmelden</button><div class="status" id="loginStatus"></div></div></div>`;
      const los = async () => {
        $('loginStatus').textContent = 'Melde an …'; $('loginStatus').className = 'status';
        const { error } = await KG.anmelden(KGW.sb, { email: $('loginEmail').value.trim(), password: $('loginPassword').value });
        if(error){ $('loginStatus').textContent = 'Login fehlgeschlagen: ' + error.message; $('loginStatus').className = 'status err'; return; }
        main.innerHTML = ''; KGW.start(fertig);
      };
      $('loginBtn').addEventListener('click', los);
      $('loginPassword').addEventListener('keydown', e => { if(e.key === 'Enter') los(); });
    },

    // Werkzeug sichtbar? (Rechte aus kg-stil.js; ohne Gruppe = sichtbar)
    darf: w => !(window.KG && KG.seiteErlaubt) || KG.seiteErlaubt(w.seite) !== false,

    async favUmschalten(key){
      const ist = KGW.favs.has(key);
      const { error } = ist
        ? await KGW.sb.from('werkzeug_favorit').delete().eq('benutzer_id', KGW.ich).eq('werkzeug_key', key)
        : await KGW.sb.from('werkzeug_favorit').insert({ werkzeug_key: key, sortierung: KGW.favs.size });
      if(error){ KGW.toast('Favorit konnte nicht gespeichert werden: ' + error.message, true); return ist; }
      if(ist) KGW.favs.delete(key); else KGW.favs.add(key);
      return !ist;
    },
    sternKnopf: (key, an) => `<button type="button" class="kgw-stern" data-stern="${key}" aria-pressed="${an}" aria-label="${an ? 'Aus Favoriten entfernen' : 'Zu Favoriten'}">${svg(pfad('stern'), 20)}</button>`,
    sternBinden(root, nachher){
      root.querySelectorAll('[data-stern]').forEach(b => b.addEventListener('click', async () => {
        b.disabled = true; const an = await KGW.favUmschalten(b.dataset.stern); b.disabled = false;
        b.setAttribute('aria-pressed', an); b.setAttribute('aria-label', an ? 'Aus Favoriten entfernen' : 'Zu Favoriten');
        if(nachher) nachher();
      }));
    },

    // Rahmen einer Werkzeug-Seite
    werkzeug(key, aufbau){
      KGW._seite = [key, aufbau]; // zum Prüfen ohne Login: KGW.start = f => f(appMain); KGW.werkzeug(...KGW._seite)
      KGW.start(main => {
        const w = LISTE.find(x => x.k === key), k = KGW.kat(w.kat);
        main.className = 'kgw'; main.style.setProperty('--kf', k.farbe);
        main.innerHTML = `<div class="kgw-titel"><a class="kgw-zurueck" href="werkzeuge-live-v1.html">${svg('<path d="M15 6l-6 6 6 6"/>', 16)}${esc(k.n)}</a>
          <h1>${esc(w.n)}</h1>${KGW.sternKnopf(key, KGW.favs.has(key))}</div><div class="kgw-stapel" id="kgwInhalt"></div>`;
        KGW.sternBinden(main);
        aufbau($('kgwInhalt'), k);
      });
    },

    karte: (titel, inhalt, id) => `<section class="kgw-karte"${id ? ` id="${id}"` : ''}><div class="kgw-kopf"><h2>${esc(titel)}</h2></div><div class="kgw-body">${inhalt}</div></section>`,
    feld: (id, label, wert, schritt) => `<div class="kgw-feld"><label for="${id}">${esc(label)}</label>
      <button type="button" class="kgw-pm" data-pm="${id}" data-schritt="${-schritt}" aria-label="weniger">−</button>
      <input class="kgw-zahl" id="${id}" inputmode="decimal" autocomplete="off" value="${esc(wert)}">
      <button type="button" class="kgw-pm" data-pm="${id}" data-schritt="${schritt}" aria-label="mehr">+</button></div>`,
    seg: (name, optionen, wert) => `<span class="kg-seg kgw-seg" role="group">${optionen.map(([v, t]) => `<button type="button" data-seg="${name}" data-v="${v}" aria-pressed="${String(v) === String(wert)}">${esc(t)}</button>`).join('')}</span>`,
    zahl: id => num($(id) && $(id).value),
    // − / + und Eingaben: neu rechnen (und Wert merken, wenn merken = Präfix für localStorage)
    binden(root, neu, merken){
      root.querySelectorAll('[data-pm]').forEach(b => b.addEventListener('click', () => {
        const inp = $(b.dataset.pm), s = parseFloat(b.dataset.schritt), d = (String(Math.abs(s)).split('.')[1] || '').length;
        inp.value = String(Math.max(0, +(num(inp.value) + s).toFixed(d))); inp.dispatchEvent(new Event('input', { bubbles: true }));
      }));
      root.querySelectorAll('input.kgw-zahl').forEach(i => i.addEventListener('input', () => { if(merken) lsSet(merken + i.id, i.value); neu(); }));
      root.querySelectorAll('[data-seg]').forEach(b => b.addEventListener('click', () => {
        root.querySelectorAll(`[data-seg="${b.dataset.seg}"]`).forEach(x => x.setAttribute('aria-pressed', x === b));
        if(merken) lsSet(merken + 'seg-' + b.dataset.seg, b.dataset.v); neu();
      }));
    },
    segWert: (root, name) => { const b = root.querySelector(`[data-seg="${name}"][aria-pressed="true"]`); return b ? b.dataset.v : null; },

    // Poolvolumen für alle Pool-Rechner: direkt oder L × B × T, wird über die Seiten hinweg gemerkt
    poolVolumen(root, neu){
      const m = lsGet('kgw-pv-seg-pvmodus', 'masse'), g = (id, alt) => lsGet('kgw-pv-' + id, alt);
      root.insertAdjacentHTML('beforeend', KGW.karte('Poolvolumen', `${KGW.seg('pvmodus', [['direkt', 'Direkt eingeben'], ['masse', 'L × B × T']], m)}
        <div id="pvDirekt">${KGW.feld('pvVol', 'Volumen (m³)', g('pvVol', '37.5'), 1)}</div>
        <div id="pvMasse" style="display:flex;flex-direction:column;gap:10px">${KGW.feld('pvL', 'Länge (m)', g('pvL', '5'), 0.5)}${KGW.feld('pvB', 'Breite (m)', g('pvB', '5'), 0.5)}${KGW.feld('pvT', 'Tiefe (m)', g('pvT', '1.5'), 0.1)}
          <div class="kgw-zeile kgw-trenn"><span>Volumen</span><b id="pvAnz"></b></div></div>`, 'pvKarte'));
      const karte = $('pvKarte');
      const wert = () => {
        const masse = KGW.segWert(karte, 'pvmodus') === 'masse';
        $('pvDirekt').classList.toggle('hidden', masse); $('pvMasse').classList.toggle('hidden', !masse);
        const v = masse ? KGW.zahl('pvL') * KGW.zahl('pvB') * KGW.zahl('pvT') : KGW.zahl('pvVol');
        $('pvAnz').textContent = fmt(v, 2) + ' m³';
        return v;
      };
      KGW.binden(karte, () => neu(wert()), 'kgw-pv-');
      return wert;
    },
    gewicht: g => g >= 1000 ? [fmt(g / 1000, 2), 'kg'] : [fmt(Math.round(g), 0), 'g']
  };
})();
