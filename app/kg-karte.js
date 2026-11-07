// Grundstückskarte (gemeinsam für Kontakte und «Pläne & Bewilligungen»)
//   KGK.koordinaten(adresse)       → { e, n, lon, lat, label } (geo.admin, LV95), im Speicher gemerkt
//   KGK.vorschau(pos, { breite })  → HTML: Luftbild + Grenzen als festes Bild (für Kacheln)
//   KGK.oeffnen({ e, n, titel })   → Vollbild-Karte: Luftbild/Karte, Grenzen, Höhenlinien, Höhe unter der Maus,
//                                    Strecke und Fläche messen (wie RegioGIS)
// Daten: swisstopo (WMTS/WMS geo.admin.ch, swissALTI3D via STAC), amtliche Vermessung (WMS geo.admin.ch).
(function(){
  const GEO = 'https://api3.geo.admin.ch/rest/services';
  const LV95 = '+proj=somerc +lat_0=46.9524055555556 +lon_0=7.43958333333333 +k_0=1 +x_0=2600000 +y_0=1200000 +ellps=bessel +towgs84=674.374,15.056,405.346,0,0,0,0 +units=m +no_defs';
  const skript = src => new Promise((ok, no) => { if(document.querySelector(`script[src="${src}"]`)) return ok(); const s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = () => no(new Error('Kartenbaustein konnte nicht geladen werden.')); document.head.appendChild(s); });
  const stil = href => { if(!document.querySelector(`link[href="${href}"]`)){ const l = document.createElement('link'); l.rel = 'stylesheet'; l.href = href; document.head.appendChild(l); } };
  const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
  let bereit = null;
  function laden(){
    if(!bereit) bereit = (async () => {
      stil('https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css');
      await Promise.all([skript('https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js'), skript('https://cdnjs.cloudflare.com/ajax/libs/proj4js/2.9.2/proj4.js')]);
    })();
    return bereit;
  }
  const zuWgs = (e, n) => proj4(LV95, 'WGS84', [e, n]);          // → [lon, lat]
  const zuLv = (lon, lat) => proj4('WGS84', LV95, [lon, lat]);    // → [e, n]

  const KOORD = {};
  async function koordinaten(adresse){
    const a = String(adresse || '').trim(); if(!a) return null;
    if(a in KOORD) return KOORD[a];
    try {
      const r = (await (await fetch(`${GEO}/api/SearchServer?type=locations&origins=address&sr=2056&limit=1&searchText=${encodeURIComponent(a)}`)).json()).results?.[0]?.attrs;
      KOORD[a] = r ? { e: r.y, n: r.x, lon: r.lon, lat: r.lat, label: String(r.label || '').replace(/<[^>]+>/g, '') } : null;
    } catch(_){ KOORD[a] = null; }
    return KOORD[a];
  }

  // Festes Vorschaubild (async): Luftbild + Grenzen/Gebäude als Linien (geodienste.ch), Punkt in der Mitte
  const VOR = {};
  const css = () => { if(!document.getElementById('kgk-css')){ const s = document.createElement('style'); s.id = 'kgk-css'; s.textContent = CSS; document.head.appendChild(s); } };
  async function vorschau(p, o = {}){
    css();
    const b = o.breite || 70, h = b * 0.62, x0 = p.e - b / 2, x1 = p.e + b / 2, y0 = p.n - h / 2, y1 = p.n + h / 2, key = `${Math.round(p.e)}|${Math.round(p.n)}|${b}`;
    if(VOR[key]) return VOR[key];
    const bild = `https://wms.geo.admin.ch/?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=ch.swisstopo.swissimage&STYLES=&CRS=EPSG:2056&BBOX=${x0},${y0},${x1},${y1}&WIDTH=560&HEIGHT=${Math.round(560 * 0.62)}&FORMAT=image/jpeg`;
    let svg = '';
    try {
      const wfs = async t => (await (await fetch(`https://geodienste.ch/db/av_0/deu?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ms:${t}&BBOX=${x0},${y0},${x1},${y1},urn:ogc:def:crs:EPSG::2056&OUTPUTFORMAT=geojson&SRSNAME=urn:ogc:def:crs:EPSG::2056`)).json()).features || [];
      const [RESF, LCSF] = await Promise.all([wfs('RESF'), wfs('LCSF')]);
      const ringe = x => x.geometry?.type === 'Polygon' ? x.geometry.coordinates : x.geometry?.type === 'MultiPolygon' ? x.geometry.coordinates.flat() : [];
      const d = f => ringe(f).map(r => 'M' + r.map(q => `${(q[0] - x0).toFixed(2)} ${(y1 - q[1]).toFixed(2)}`).join('L') + 'Z').join('');
      svg = `<svg viewBox="0 0 ${b} ${h}" preserveAspectRatio="none" aria-hidden="true">${LCSF.filter(f => f.properties.Art === 'Gebaeude').map(f => `<path d="${d(f)}" fill="none" stroke="#ffb3c0" stroke-width="0.35"/>`).join('')}${RESF.map(f => `<path d="${d(f)}" fill="none" stroke="#ffe14d" stroke-width="0.45"/>`).join('')}</svg>`;
    } catch(_){}
    return (VOR[key] = `<span class="kgk-vor"><img src="${bild}" alt="" loading="lazy">${svg}<i></i></span>`);
  }

  // Höhenmodell swissALTI3D (0.5 m) für ein Rechteck in LV95; neueste Befliegung je Kachel
  async function hoehenGitter(x0, y0, x1, y1){
    await skript('https://cdn.jsdelivr.net/npm/geotiff@2.1.3/dist-browser/geotiff.js');
    const [l0, p0] = zuWgs(x0, y0), [l1, p1] = zuWgs(x1, y1);
    const stac = await (await fetch(`https://data.geo.admin.ch/api/stac/v0.9/collections/ch.swisstopo.swissalti3d/items?bbox=${l0},${p0},${l1},${p1}&limit=100`)).json();
    const RES = 0.5, nc = Math.ceil((x1 - x0) / RES) + 1, nr = Math.ceil((y1 - y0) / RES) + 1, roh = new Float32Array(nc * nr).fill(NaN);
    let jahr = '';
    for(let kx = Math.floor(x0 / 1000); kx <= Math.floor(x1 / 1000); kx++) for(let ky = Math.floor(y0 / 1000); ky <= Math.floor(y1 / 1000); ky++){
      const it = (stac.features || []).filter(f => f.id.endsWith(`_${kx}-${ky}`)).sort((p, q) => q.id.localeCompare(p.id))[0]; if(!it) continue;
      const href = Object.values(it.assets).find(s => /_0\.5_2056_\d+\.tif$/.test(s.href))?.href; if(!href) continue;
      jahr = it.id.match(/_(\d{4})_/)?.[1] || jahr;
      const bild = await (await GeoTIFF.fromUrl(href)).getImage(), [tx0, , , ty1] = bild.getBoundingBox(), tw = bild.getWidth(), th = bild.getHeight();
      const cA = Math.max(0, Math.floor((x0 - tx0) / RES)), cE = Math.min(tw, Math.ceil((x1 - tx0) / RES) + 1), rA = Math.max(0, Math.floor((ty1 - y1) / RES)), rE = Math.min(th, Math.ceil((ty1 - y0) / RES) + 1);
      if(cA >= cE || rA >= rE) continue;
      const [w] = await bild.readRasters({ window: [cA, rA, cE, rE] }), ww = cE - cA;
      for(let r = rA; r < rE; r++) for(let k = cA; k < cE; k++){
        const gk = Math.round((tx0 + (k + 0.5) * RES - x0) / RES - 0.5), gr = Math.round((y1 - (ty1 - (r + 0.5) * RES)) / RES - 0.5);
        if(gk >= 0 && gk < nc && gr >= 0 && gr < nr) roh[gr * nc + gk] = w[(r - rA) * ww + (k - cA)];
      }
    }
    const z = new Float32Array(nc * nr);   // leicht glätten (3x3)
    for(let r = 0; r < nr; r++) for(let k = 0; k < nc; k++){ let s = 0, n = 0;
      for(let dr = -1; dr <= 1; dr++) for(let dk = -1; dk <= 1; dk++){ const v = roh[(r + dr) * nc + k + dk]; if(r + dr >= 0 && r + dr < nr && k + dk >= 0 && k + dk < nc && !isNaN(v)){ s += v; n++; } }
      z[r * nc + k] = n ? s / n : NaN; }
    const gx = k => x0 + (k + 0.5) * RES, gy = r => y1 - (r + 0.5) * RES;
    const hoehe = (x, y) => { const k = (x - x0) / RES - 0.5, r = (y1 - y) / RES - 0.5, k0 = Math.floor(k), r0 = Math.floor(r), fk = k - k0, fr = r - r0;
      if(k0 < 0 || r0 < 0 || k0 + 1 >= nc || r0 + 1 >= nr) return NaN;
      return (z[r0 * nc + k0] * (1 - fk) + z[r0 * nc + k0 + 1] * fk) * (1 - fr) + (z[(r0 + 1) * nc + k0] * (1 - fk) + z[(r0 + 1) * nc + k0 + 1] * fk) * fr; };
    // Höhenlinien (Marching Squares) als Liste von Segmenten in LV95
    const linien = stufe => { let zmin = Infinity, zmax = -Infinity; z.forEach(v => { if(!isNaN(v)){ if(v < zmin) zmin = v; if(v > zmax) zmax = v; } });
      const out = [];
      for(let lv = Math.ceil(zmin / stufe) * stufe; lv <= zmax; lv += stufe){ const seg = [];
        for(let r = 0; r < nr - 1; r++) for(let k = 0; k < nc - 1; k++){
          const a = z[r * nc + k], b = z[r * nc + k + 1], c = z[(r + 1) * nc + k + 1], d = z[(r + 1) * nc + k], p = [];
          if(isNaN(a + b + c + d)) continue;
          const kante = (va, vb, xa, ya, xb, yb) => { if((va - lv) * (vb - lv) < 0){ const t = (lv - va) / (vb - va); p.push([xa + (xb - xa) * t, ya + (yb - ya) * t]); } };
          kante(a, b, gx(k), gy(r), gx(k + 1), gy(r)); kante(b, c, gx(k + 1), gy(r), gx(k + 1), gy(r + 1)); kante(c, d, gx(k + 1), gy(r + 1), gx(k), gy(r + 1)); kante(d, a, gx(k), gy(r + 1), gx(k), gy(r));
          for(let i = 0; i + 1 < p.length; i += 2) seg.push([p[i], p[i + 1]]);
        }
        out.push({ hoehe: lv, seg });
      }
      return { zmin, zmax, out }; };
    return { hoehe, linien, jahr, x0, y0, x1, y1 };
  }

  const fm = m => m >= 1000 ? (m / 1000).toFixed(3) + ' km' : m.toFixed(2) + ' m';
  const fa = q => q >= 10000 ? (q / 10000).toFixed(3) + ' ha' : q.toFixed(1) + ' m²';

  // Höhenkoten: Schnittpunkte der Höhenlinien mit der Grenze der eigenen Parzelle und den Gebäuden darin (Abstand mind. 1.5 m), in LV95
  const innenRing = (x, y, rg) => { let r = false; for(let i = 0, j = rg.length - 1; i < rg.length; j = i++){ const [xi, yi] = rg[i], [xj, yj] = rg[j]; if(((yi > y) !== (yj > y)) && x < (xj - xi) * (y - yi) / (yj - yi) + xi) r = !r; } return r; };
  function kotenPunkte(linien, eigen, haeuser){
    const ringe = [eigen, ...haeuser.flat().filter(rg => { const c = rg.reduce((s, p) => [s[0] + p[0] / rg.length, s[1] + p[1] / rg.length], [0, 0]); return innenRing(c[0], c[1], eigen); })];
    const kanten = []; ringe.forEach(rg => { for(let i = 0; i + 1 < rg.length; i++){ const a = rg[i], b = rg[i + 1]; kanten.push([a, b, Math.min(a[0], b[0]), Math.max(a[0], b[0]), Math.min(a[1], b[1]), Math.max(a[1], b[1])]); } });
    const schnitt = (p, q, a, b) => { const d = (q[0] - p[0]) * (b[1] - a[1]) - (q[1] - p[1]) * (b[0] - a[0]); if(Math.abs(d) < 1e-12) return null;
      const t = ((a[0] - p[0]) * (b[1] - a[1]) - (a[1] - p[1]) * (b[0] - a[0])) / d, u = ((a[0] - p[0]) * (q[1] - p[1]) - (a[1] - p[1]) * (q[0] - p[0])) / d;
      return t >= 0 && t <= 1 && u >= 0 && u <= 1 ? [p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])] : null; };
    const punkte = [];
    linien.forEach(l => l.seg.forEach(([p, q]) => { const sx0 = Math.min(p[0], q[0]), sx1 = Math.max(p[0], q[0]), sy0 = Math.min(p[1], q[1]), sy1 = Math.max(p[1], q[1]);
      kanten.forEach(([a, b, kx0, kx1, ky0, ky1]) => { if(sx1 < kx0 || sx0 > kx1 || sy1 < ky0 || sy0 > ky1) return; const s = schnitt(p, q, a, b);
        if(s && !punkte.some(o => Math.hypot(o[0] - s[0], o[1] - s[1]) < 1.5)) punkte.push([s[0], s[1], l.hoehe]); }); }));
    return punkte;
  }

  async function oeffnen(o){
    await laden();
    if(!o.e && o.adresse){ const p = await koordinaten(o.adresse); if(!p) throw new Error('Adresse nicht gefunden.'); Object.assign(o, p); }
    const [lon, lat] = zuWgs(o.e, o.n);
    css();
    // Eigenes Fenster (etwa halber Bildschirm) über abgedunkeltem Hintergrund: links das Menü, rechts nur die Karte
    const h = document.createElement('div'); h.className = 'kgk-ovl';
    h.innerHTML = `<div class="kgk-fen" role="dialog" aria-label="Karte">
      <aside class="kgk-menu"><div class="kgk-t"><b>${esc(o.titel || 'Grundstück')}</b><small>${esc(o.untertitel || '')}</small><small data-info></small></div>
        <b>Werkzeug</b>
        <div class="kgk-werk" role="group" aria-label="Werkzeug"><button type="button" data-w="pan" aria-pressed="true">Verschieben</button><button type="button" data-w="strecke" aria-pressed="false">Strecke messen</button><button type="button" data-w="flaeche" aria-pressed="false">Fläche messen</button><button type="button" data-w="weg">Messungen löschen</button></div>
        <b>Hintergrund</b>
        ${[['luft', 'Luftbild'], ['farbe', 'Landeskarte'], ['grau', 'Landeskarte grau'], ['weiss', 'Keiner']].map(([k, t], i) => `<label><input type="radio" name="kgk-bg" value="${k}"${i ? '' : ' checked'}> ${t}</label>`).join('')}
        <label class="kgk-dk">Deckkraft <input type="range" min="10" max="100" value="100" data-dk></label>
        <b>Darüber</b>
        <label><input type="checkbox" data-av checked> Grenzen &amp; Gebäude</label>
        <label><input type="checkbox" data-hl> Höhenlinien</label>
        <span class="kgk-info" data-hlinfo></span>
        <b>Drucken</b>
        <label>Blatt <select data-blatt style="flex:1;min-width:0"><option value="a4h">A4 hoch</option><option value="a4q">A4 quer</option><option value="a3h">A3 hoch</option><option value="a3q">A3 quer</option></select></label>
        <label>Massstab <select data-mst style="flex:1;min-width:0"><option value="100">1:100</option><option value="200" selected>1:200</option><option value="500">1:500</option><option value="1000">1:1000</option></select></label>
        <button type="button" class="kgk-knopf" data-rahmen>Rahmen zeigen</button>
        <button type="button" class="kgk-knopf" data-druck>PDF erstellen</button>
        <a class="kgk-ext" target="_blank" rel="noopener" href="https://regiogis-beo.ch/?x=${Math.round(o.e)}&y=${Math.round(o.n)}&z=13">Im RegioGIS öffnen (Leitungen)</a></aside>
      <div class="kgk-rechts"><div class="kgk-karte"></div>
        <button type="button" class="kg-ibtn kgk-zu" data-zu aria-label="Schliessen" title="Schliessen (Esc)">${window.KG && KG.icon ? KG.icon('x', 14) : '×'}</button>
        <div class="kgk-status"><span data-hoehe></span><span data-mess></span></div></div></div>`;
    document.body.appendChild(h);
    h.addEventListener('mousedown', e => { if(e.target === h) zu(); });
    const map = L.map(h.querySelector('.kgk-karte'), { zoomControl: true, maxZoom: 22, doubleClickZoom: false }).setView([lat, lon], 20);
    const wmts = (l, f, max) => L.tileLayer(`https://wmts.geo.admin.ch/1.0.0/${l}/default/current/3857/{z}/{x}/{y}.${f}`, { maxNativeZoom: max, maxZoom: 22, attribution: '© swisstopo' });
    const BG = { luft: wmts('ch.swisstopo.swissimage', 'jpeg', 20), farbe: wmts('ch.swisstopo.pixelkarte-farbe', 'jpeg', 18), grau: wmts('ch.swisstopo.pixelkarte-grau', 'jpeg', 18), weiss: null };
    let bg = BG.luft; bg.addTo(map);
    // Amtliche Vermessung als Linien (geodienste.ch, WFS): Grenzen, Gebäude, Parzellennummern – durchsichtig über jedem Hintergrund
    const av = L.layerGroup().addTo(map); let avT = null, avNr = 0;
    // Grenzen und Gebäude schwarz (auf dem Luftbild gut sichtbar); Parzellennummern auf dem Luftbild weiss
    const avFarbe = () => ({ g: '#111111', h: '#000000', t: bg === BG.luft ? 'hell' : 'dunkel' });
    let HAUS_LV = [], EIGEN_LV = null;   // für die Höhenkoten an Grenze und Gebäuden der eigenen Parzelle
    const avLaden = async () => {
      av.clearLayers(); if(!map.hasLayer(av) || map.getZoom() < 17) return;
      const b = map.getBounds(), [x0, y0] = zuLv(b.getWest(), b.getSouth()), [x1, y1] = zuLv(b.getEast(), b.getNorth()), nr = ++avNr;
      const wfs = async t => (await (await fetch(`https://geodienste.ch/db/av_0/deu?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ms:${t}&BBOX=${x0},${y0},${x1},${y1},urn:ogc:def:crs:EPSG::2056&OUTPUTFORMAT=geojson&SRSNAME=urn:ogc:def:crs:EPSG::2056`)).json()).features || [];
      const [RESF, LCSF, OSNR] = await Promise.all(['RESF', 'LCSF', 'OSNR'].map(t => wfs(t).catch(() => [])));
      if(nr !== avNr) return; av.clearLayers();
      const f = avFarbe(), wg = ring => ring.map(p => zuWgs(p[0], p[1]).reverse());
      const ringe = x => x.geometry?.type === 'Polygon' ? x.geometry.coordinates : x.geometry?.type === 'MultiPolygon' ? x.geometry.coordinates.flat() : [];
      const haus = LCSF.filter(x => x.properties.Art === 'Gebaeude');
      HAUS_LV = haus.map(ringe);
      haus.forEach(x => av.addLayer(L.polygon(ringe(x).map(wg), { color: f.h, weight: 2, fill: f.t === 'dunkel', fillColor: '#dfe3e8', fillOpacity: .7, interactive: false })));
      RESF.forEach(x => av.addLayer(L.polygon(ringe(x).map(wg), { color: f.g, weight: 1.6, fill: false, interactive: false })));
      kotenZeichnen();
      OSNR.forEach(x => { const [e, n] = x.geometry.coordinates; av.addLayer(L.marker(zuWgs(e, n).reverse(), { interactive: false, icon: L.divIcon({ className: 'kgk-nr ' + f.t, html: `<span>${esc(x.properties.Nummer)}</span>`, iconSize: null }) })); });
    };
    map.on('moveend', () => { clearTimeout(avT); avT = setTimeout(avLaden, 250); });
    avLaden();
    L.circleMarker([lat, lon], { radius: 5, color: '#fff', weight: 2, fillColor: '#323e4e', fillOpacity: 1 }).addTo(map);
    // eigene Parzelle hervorheben
    let PARZ = null;
    fetch(`${GEO}/api/MapServer/identify?geometry=${o.e},${o.n}&geometryType=esriGeometryPoint&sr=2056&layers=all:ch.kantone.cadastralwebmap-farbe&tolerance=0&returnGeometry=true&geometryFormat=geojson&imageDisplay=500,500,96&mapExtent=${o.e - 50},${o.n - 50},${o.e + 50},${o.n + 50}`)
      .then(r => r.json()).then(d => { const f = d.results?.[0]; if(!f) return;
        EIGEN_LV = f.geometry.type === 'MultiPolygon' ? f.geometry.coordinates[0][0] : f.geometry.coordinates[0]; PARZ = f.properties;
        L.polygon(EIGEN_LV.map(p => zuWgs(p[0], p[1]).reverse()), { color: '#4F80C2', weight: 4, fill: false, interactive: false }).addTo(map);
        h.querySelector('[data-info]').textContent = `Parzelle ${f.properties.number}${f.properties.egris_egrid ? ' · ' + f.properties.egris_egrid : ''}`; kotenZeichnen(); }).catch(() => {});
    setTimeout(() => map.invalidateSize(), 50);

    // Hintergrund, Deckkraft, Ebenen
    let dk = 1;
    h.querySelectorAll('[name="kgk-bg"]').forEach(r => r.onchange = () => { if(bg) map.removeLayer(bg); bg = BG[r.value]; if(bg){ bg.setOpacity(dk); bg.addTo(map); bg.bringToBack(); } avLaden(); hlZeichnen(); });
    h.querySelector('[data-dk]').oninput = e => { dk = e.target.value / 100; if(bg) bg.setOpacity(dk); };
    h.querySelector('[data-av]').onchange = e => { if(e.target.checked){ av.addTo(map); avLaden(); } else map.removeLayer(av); };
    // Höhenlinien gelb (auf der Landeskarte goldbraun), ganze Meter kräftiger
    let HL = null, KO = null, gitter = null, LINIEN = null, STUFE = 0.5;
    const hlFarbe = meter => bg === BG.luft || !bg ? (meter ? '#ffe14d' : '#fff3a6') : (meter ? '#8a6410' : '#b88a12');
    const hlZeichnen = () => { if(HL) map.removeLayer(HL); HL = null; if(!LINIEN) return; HL = L.layerGroup();
      LINIEN.forEach(l => { const meter = Math.abs(l.hoehe - Math.round(l.hoehe)) < 1e-6;
        L.polyline(l.seg.map(([p, q]) => [zuWgs(p[0], p[1]).reverse(), zuWgs(q[0], q[1]).reverse()]), { color: hlFarbe(meter), weight: meter ? 2 : 1, opacity: .95, interactive: false }).addTo(HL); });
      HL.addTo(map); kotenZeichnen(); };
    const hlLaden = async () => {
      const b = map.getBounds(), [x0, y0] = zuLv(b.getWest(), b.getSouth()), [x1, y1] = zuLv(b.getEast(), b.getNorth());
      const info = h.querySelector('[data-hlinfo]');
      if(x1 - x0 > 400 || y1 - y0 > 400){ info.textContent = 'Für Höhenlinien näher heranzoomen.'; return; }
      info.textContent = 'Höhen werden geladen …';
      try {
        gitter = await hoehenGitter(x0 - 10, y0 - 10, x1 + 10, y1 + 10);
        STUFE = Math.max(x1 - x0, y1 - y0) < 120 ? 0.25 : 0.5; const r = gitter.linien(STUFE); LINIEN = r.out;
        hlZeichnen();
        info.textContent = `alle ${STUFE} m · ${r.zmin.toFixed(1)}–${r.zmax.toFixed(1)} m ü. M. · swissALTI3D ${gitter.jahr}, ca. ±0.25 m`;
      } catch(err){ info.textContent = 'Höhen nicht verfügbar: ' + err.message; }
    };
    // Höhenkoten: wo eine Höhenlinie die Grenze der eigenen Parzelle oder ein Gebäude darin schneidet (klein, Abstand mind. 1.5 m)
    function kotenZeichnen(){
      if(KO) map.removeLayer(KO); KO = null; if(!LINIEN || !EIGEN_LV) return;
      const punkte = kotenPunkte(LINIEN, EIGEN_LV, HAUS_LV);
      KO = L.layerGroup(punkte.map(([x, y, z]) => L.marker(zuWgs(x, y).reverse(), { interactive: false, icon: L.divIcon({ className: 'kgk-ko', html: `<i></i><span>${z.toFixed(2)}</span>`, iconSize: null }) }))).addTo(map);
    }
    h.querySelector('[data-hl]').onchange = e => { if(e.target.checked) hlLaden(); else { if(HL) map.removeLayer(HL); if(KO) map.removeLayer(KO); HL = KO = null; gitter = LINIEN = null; h.querySelector('[data-hlinfo]').textContent = ''; h.querySelector('[data-hoehe]').textContent = ''; } };
    map.on('mousemove', e => { if(!gitter) return; const [x, y] = zuLv(e.latlng.lng, e.latlng.lat), z = gitter.hoehe(x, y);
      h.querySelector('[data-hoehe]').textContent = isNaN(z) ? 'Höhe: ausserhalb' : `Höhe: ${z.toFixed(2)} m ü. M.`; });

    // Messen: Strecke (Segmente + Total) und Fläche (Fläche + Umfang); Doppelklick beendet, Esc bricht ab, Rücktaste löscht den letzten Punkt
    let werkzeug = 'pan', punkte = [], live = null, gruppe = L.layerGroup().addTo(map), labels = [];
    const lv = ll => zuLv(ll.lng, ll.lat);
    const laenge = pp => pp.slice(1).reduce((s, p, i) => { const a = lv(pp[i]), b = lv(p); return s + Math.hypot(b[0] - a[0], b[1] - a[1]); }, 0);
    const flaeche = pp => { const q = pp.map(lv); let s = 0; for(let i = 0; i < q.length; i++){ const a = q[i], b = q[(i + 1) % q.length]; s += a[0] * b[1] - b[0] * a[1]; } return Math.abs(s) / 2; };
    const marke = (ll, text, cls = '') => L.marker(ll, { interactive: false, icon: L.divIcon({ className: 'kgk-lab ' + cls, html: `<span>${text}</span>`, iconSize: null }) });
    const zeichneLive = mit => { if(live) gruppe.removeLayer(live); labels.forEach(l => gruppe.removeLayer(l)); labels = [];
      const pp = mit ? [...punkte, mit] : punkte; if(!pp.length) return;
      live = werkzeug === 'flaeche' && pp.length > 2 ? L.polygon(pp, { color: '#ff7a00', weight: 2, dashArray: '6 4', fillOpacity: .15 }) : L.polyline(pp, { color: '#ff7a00', weight: 2, dashArray: '6 4' });
      gruppe.addLayer(live);
      pp.slice(1).forEach((p, i) => { const a = lv(pp[i]), b = lv(p), d = Math.hypot(b[0] - a[0], b[1] - a[1]); if(d > 0.3) labels.push(marke(L.latLng((pp[i].lat + p.lat) / 2, (pp[i].lng + p.lng) / 2), d.toFixed(2) + ' m', 'seg').addTo(gruppe)); });
      h.querySelector('[data-mess]').textContent = werkzeug === 'flaeche' && pp.length > 2 ? `Fläche ${fa(flaeche(pp))} · Umfang ${fm(laenge([...pp, pp[0]]))}` : `Strecke ${fm(laenge(pp))}`; };
    const MESS = [];   // abgeschlossene Messungen in LV95 (für den Ausdruck)
    const fertig = () => { if((werkzeug === 'flaeche' && punkte.length > 2) || (werkzeug === 'strecke' && punkte.length > 1)) MESS.push({ typ: werkzeug, pts: punkte.map(lv) });
      if(werkzeug === 'flaeche' && punkte.length > 2){ if(live) gruppe.removeLayer(live); labels.forEach(l => gruppe.removeLayer(l)); labels = [];
        gruppe.addLayer(L.polygon(punkte, { color: '#ff7a00', weight: 2, fillOpacity: .18 }));
        punkte.forEach((p, i) => { const q = punkte[(i + 1) % punkte.length], a = lv(p), b = lv(q), d = Math.hypot(b[0] - a[0], b[1] - a[1]); if(d > 0.3) gruppe.addLayer(marke(L.latLng((p.lat + q.lat) / 2, (p.lng + q.lng) / 2), d.toFixed(2) + ' m', 'seg')); });
        gruppe.addLayer(marke(L.polygon(punkte).getBounds().getCenter(), fa(flaeche(punkte)), 'tot')); }
      else if(werkzeug === 'strecke' && punkte.length > 1){ if(live) gruppe.removeLayer(live); live = null; labels.forEach(l => gruppe.removeLayer(l)); labels = [];
        gruppe.addLayer(L.polyline(punkte, { color: '#ff7a00', weight: 2.5 }));
        punkte.slice(1).forEach((p, i) => { const a = lv(punkte[i]), b = lv(p), d = Math.hypot(b[0] - a[0], b[1] - a[1]); if(d > 0.3) gruppe.addLayer(marke(L.latLng((punkte[i].lat + p.lat) / 2, (punkte[i].lng + p.lng) / 2), d.toFixed(2) + ' m', 'seg')); });
        if(punkte.length > 2) gruppe.addLayer(marke(punkte[punkte.length - 1], 'Total ' + fm(laenge(punkte)), 'tot')); }
      else { if(live) gruppe.removeLayer(live); labels.forEach(l => gruppe.removeLayer(l)); labels = []; }
      punkte.forEach(p => gruppe.addLayer(L.circleMarker(p, { radius: 3, color: '#ff7a00', weight: 1, fillOpacity: 1, interactive: false })));
      live = null; labels = []; punkte = []; };
    map.on('click', e => { if(werkzeug === 'pan') return; punkte.push(e.latlng); gruppe.addLayer(L.circleMarker(e.latlng, { radius: 3, color: '#ff7a00', weight: 1, fillOpacity: 1, interactive: false })); zeichneLive(); });
    map.on('mousemove', e => { if(werkzeug !== 'pan' && punkte.length) zeichneLive(e.latlng); });
    // Doppelklick: der zweite Klick hat den letzten Punkt doppelt gesetzt → weg damit, dann abschliessen
    map.on('dblclick', e => { if(werkzeug === 'pan') return; L.DomEvent.stop(e);
      const n = punkte.length; if(n > 1 && map.latLngToContainerPoint(punkte[n - 1]).distanceTo(map.latLngToContainerPoint(punkte[n - 2])) < 6) punkte.pop();
      fertig(); });
    const setW = w => { if(w === 'weg'){ gruppe.clearLayers(); punkte = []; live = null; labels = []; MESS.length = 0; h.querySelector('[data-mess]').textContent = ''; return; }
      fertig(); werkzeug = w; h.querySelectorAll('[data-w]').forEach(b => b.dataset.w !== 'weg' && b.setAttribute('aria-pressed', String(b.dataset.w === w)));
      h.querySelector('.kgk-karte').style.cursor = w === 'pan' ? '' : 'crosshair'; };
    h.querySelectorAll('[data-w]').forEach(b => b.onclick = () => setW(b.dataset.w));
    // Ausdruck: Rahmen (Kartenfeld des Blatts im gewählten Massstab) auf der Karte verschieben, dann PDF
    const BLATT = { a4h: [210, 297], a4q: [297, 210], a3h: [297, 420], a3q: [420, 297] }, RAND = 10, FUSS = 24;
    let rahmen = null, rz = [o.e, o.n];
    const feld = () => { const [W, H] = BLATT[h.querySelector('[data-blatt]').value], m = +h.querySelector('[data-mst]').value;
      return { W, H, m, mw: W - 2 * RAND, mh: H - 2 * RAND - FUSS, bw: (W - 2 * RAND) * m / 1000, bh: (H - 2 * RAND - FUSS) * m / 1000 }; };
    const rahmenEcken = () => { const f = feld(), [cx, cy] = rz; return [[cx - f.bw / 2, cy - f.bh / 2], [cx + f.bw / 2, cy - f.bh / 2], [cx + f.bw / 2, cy + f.bh / 2], [cx - f.bw / 2, cy + f.bh / 2]]; };
    const rahmenZeichnen = () => { if(!rahmen) return; rahmen.setLatLngs(rahmenEcken().map(p => zuWgs(p[0], p[1]).reverse())); };
    const rahmenAn = () => { if(rahmen) return;
      rahmen = L.polygon(rahmenEcken().map(p => zuWgs(p[0], p[1]).reverse()), { className: 'kgk-rahmen', color: '#ff7a00', weight: 2, dashArray: '8 5', fillColor: '#ff7a00', fillOpacity: .06 }).addTo(map);
      map.fitBounds(rahmen.getBounds(), { padding: [30, 30] });
      let start = null;
      rahmen.on('mousedown', e => { if(werkzeug !== 'pan') return; L.DomEvent.stop(e); map.dragging.disable(); start = { p: lv(e.latlng), z: [...rz] }; });
      map.on('mousemove', e => { if(!start) return; const p = lv(e.latlng); rz = [start.z[0] + p[0] - start.p[0], start.z[1] + p[1] - start.p[1]]; rahmenZeichnen(); });
      map.on('mouseup', () => { if(start){ start = null; map.dragging.enable(); } });
      h.querySelector('[data-rahmen]').classList.add('an'); h.querySelector('[data-rahmen]').textContent = 'Rahmen ausblenden'; };
    const rahmenAus = () => { if(rahmen) map.removeLayer(rahmen); rahmen = null; h.querySelector('[data-rahmen]').classList.remove('an'); h.querySelector('[data-rahmen]').textContent = 'Rahmen zeigen'; };
    h.querySelector('[data-rahmen]').onclick = () => rahmen ? rahmenAus() : rahmenAn();
    h.querySelector('[data-blatt]').onchange = h.querySelector('[data-mst]').onchange = () => { if(rahmen){ rahmenZeichnen(); map.fitBounds(rahmen.getBounds(), { padding: [30, 30] }); } else rahmenAn(); };
    h.querySelector('[data-druck]').onclick = async e => { const k = e.target, alt = k.textContent; if(!rahmen){ rahmenAn(); return; }
      k.textContent = 'PDF wird erstellt …'; k.style.pointerEvents = 'none';
      try { await druck(); } catch(err){ alert('PDF: ' + err.message); } finally { k.textContent = alt; k.style.pointerEvents = ''; } };
    async function druck(){
      await skript('https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js');
      const f = feld(), PX = 8, [cx, cy] = rz, x0 = cx - f.bw / 2, x1 = cx + f.bw / 2, y0 = cy - f.bh / 2, y1 = cy + f.bh / 2;
      const c = document.createElement('canvas'); c.width = f.W * PX; c.height = f.H * PX; const g = c.getContext('2d');
      g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height);
      const ox = RAND * PX, oy = RAND * PX, MW = f.mw * PX, MH = f.mh * PX, s = MW / f.bw;
      const px = x => ox + (x - x0) * s, py = y => oy + (y1 - y) * s;
      g.save(); g.beginPath(); g.rect(ox, oy, MW, MH); g.clip();
      // Hintergrund als Bild in Druckauflösung (geo.admin WMS), mit der eingestellten Deckkraft
      const bgName = h.querySelector('[name="kgk-bg"]:checked').value, WMS = { luft: 'ch.swisstopo.swissimage', farbe: 'ch.swisstopo.pixelkarte-farbe', grau: 'ch.swisstopo.pixelkarte-grau' }[bgName];
      if(WMS){ const im = new Image(); im.crossOrigin = 'anonymous';
        im.src = `https://wms.geo.admin.ch/?SERVICE=WMS&REQUEST=GetMap&VERSION=1.3.0&LAYERS=${WMS}&STYLES=&CRS=EPSG:2056&BBOX=${x0},${y0},${x1},${y1}&WIDTH=${Math.min(Math.round(MW), 4000)}&HEIGHT=${Math.min(Math.round(MH), 4000)}&FORMAT=image/jpeg`;
        await im.decode(); g.globalAlpha = dk; g.drawImage(im, ox, oy, MW, MH); g.globalAlpha = 1; }
      const wg = bgName === 'luft';
      // Höhenlinien und Koten
      let linien = null;
      if(h.querySelector('[data-hl]').checked && f.bw <= 400 && f.bh <= 400){
        const gt = await hoehenGitter(x0 - 2, y0 - 2, x1 + 2, y1 + 2); linien = gt.linien(STUFE).out;
        linien.forEach(l => { const meter = Math.abs(l.hoehe - Math.round(l.hoehe)) < 1e-6; g.beginPath();
          l.seg.forEach(([p, q]) => { g.moveTo(px(p[0]), py(p[1])); g.lineTo(px(q[0]), py(q[1])); });
          g.strokeStyle = wg ? (meter ? '#ffe14d' : '#fff3a6') : (meter ? '#8a6410' : '#b88a12'); g.lineWidth = meter ? 2.4 : 1.2; g.stroke(); });
      }
      // Grenzen, Gebäude, Nummern (amtliche Vermessung)
      const wfs = async t => (await (await fetch(`https://geodienste.ch/db/av_0/deu?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ms:${t}&BBOX=${x0},${y0},${x1},${y1},urn:ogc:def:crs:EPSG::2056&OUTPUTFORMAT=geojson&SRSNAME=urn:ogc:def:crs:EPSG::2056`)).json()).features || [];
      let haeuser = [];
      if(h.querySelector('[data-av]').checked){
        const [RESF, LCSF, OSNR] = await Promise.all(['RESF', 'LCSF', 'OSNR'].map(t => wfs(t).catch(() => [])));
        const ringe = x => x.geometry?.type === 'Polygon' ? x.geometry.coordinates : x.geometry?.type === 'MultiPolygon' ? x.geometry.coordinates.flat() : [];
        const pfad = rr => { g.beginPath(); rr.forEach(r => r.forEach((p, i) => i ? g.lineTo(px(p[0]), py(p[1])) : g.moveTo(px(p[0]), py(p[1])))); };
        const hs = LCSF.filter(x => x.properties.Art === 'Gebaeude'); haeuser = hs.map(ringe);
        hs.forEach(x => { pfad(ringe(x)); if(!wg){ g.fillStyle = 'rgba(223,227,232,.7)'; g.fill('evenodd'); } g.lineWidth = 2.6; g.strokeStyle = '#000'; g.stroke(); });
        RESF.forEach(x => { pfad(ringe(x)); g.lineWidth = 2; g.strokeStyle = '#111'; g.stroke(); });
        g.font = 'bold 26px Arial'; g.textAlign = 'center'; g.textBaseline = 'middle';
        OSNR.forEach(x => { const [e, n] = x.geometry.coordinates; g.lineWidth = 4; g.strokeStyle = wg ? '#000' : '#fff'; g.strokeText(x.properties.Nummer, px(e), py(n)); g.fillStyle = wg ? '#fff' : '#323e4e'; g.fillText(x.properties.Nummer, px(e), py(n)); });
      }
      if(EIGEN_LV){ g.beginPath(); EIGEN_LV.forEach((p, i) => i ? g.lineTo(px(p[0]), py(p[1])) : g.moveTo(px(p[0]), py(p[1]))); g.lineWidth = 5; g.strokeStyle = '#4F80C2'; g.stroke(); }
      if(linien && EIGEN_LV){ g.font = 'bold 15px Arial'; g.textAlign = 'left'; g.textBaseline = 'alphabetic';
        kotenPunkte(linien, EIGEN_LV, haeuser).forEach(([x, y, z]) => { g.fillStyle = '#ffe14d'; g.strokeStyle = '#000'; g.lineWidth = 1.5; g.beginPath(); g.arc(px(x), py(y), 4, 0, 7); g.fill(); g.stroke();
          g.lineWidth = 4; g.strokeStyle = '#fff'; g.strokeText(z.toFixed(2), px(x) + 6, py(y) - 6); g.fillStyle = '#000'; g.fillText(z.toFixed(2), px(x) + 6, py(y) - 6); }); }
      // Messungen
      g.font = 'bold 17px Arial'; g.textAlign = 'center'; g.textBaseline = 'middle';
      MESS.forEach(m => { const pp = m.typ === 'flaeche' ? [...m.pts, m.pts[0]] : m.pts; g.beginPath(); pp.forEach((p, i) => i ? g.lineTo(px(p[0]), py(p[1])) : g.moveTo(px(p[0]), py(p[1])));
        g.lineWidth = 3; g.strokeStyle = '#ff7a00'; g.stroke();
        pp.slice(1).forEach((p, i) => { const q = pp[i], d = Math.hypot(p[0] - q[0], p[1] - q[1]); if(d < 0.3) return; const t = d.toFixed(2) + ' m', w = g.measureText(t).width + 10, mx = (px(p[0]) + px(q[0])) / 2, my = (py(p[1]) + py(q[1])) / 2;
          g.fillStyle = '#fff'; g.fillRect(mx - w / 2, my - 12, w, 24); g.strokeStyle = '#ff7a00'; g.lineWidth = 1.5; g.strokeRect(mx - w / 2, my - 12, w, 24); g.fillStyle = '#7a3a00'; g.fillText(t, mx, my); });
        if(m.typ === 'flaeche'){ let a = 0; m.pts.forEach((p, i) => { const q = m.pts[(i + 1) % m.pts.length]; a += p[0] * q[1] - q[0] * p[1]; }); a = Math.abs(a) / 2;
          const sx = m.pts.reduce((s, p) => s + px(p[0]), 0) / m.pts.length, sy = m.pts.reduce((s, p) => s + py(p[1]), 0) / m.pts.length, t = fa(a), w = g.measureText(t).width + 14;
          g.fillStyle = '#ff7a00'; g.fillRect(sx - w / 2, sy - 14, w, 28); g.fillStyle = '#fff'; g.fillText(t, sx, sy); } });
      g.restore();
      // Rahmen, Nordpfeil, Massstabsbalken, Fusszeile
      g.strokeStyle = '#323e4e'; g.lineWidth = 2; g.strokeRect(ox, oy, MW, MH);
      const nx = ox + MW - 40, ny = oy + 60; g.beginPath(); g.moveTo(nx, ny - 38); g.lineTo(nx + 15, ny + 14); g.lineTo(nx, ny); g.lineTo(nx - 15, ny + 14); g.closePath();
      g.fillStyle = '#323e4e'; g.strokeStyle = '#fff'; g.lineWidth = 3; g.stroke(); g.fill(); g.font = 'bold 24px Arial'; g.textAlign = 'center'; g.lineWidth = 4; g.strokeText('N', nx, ny + 38); g.fillText('N', nx, ny + 38);
      const fy = oy + MH + 8 * PX, SB = [1, 2, 5, 10, 20, 50, 100].find(v => v * s >= 25 * PX) || 100;
      g.textAlign = 'left'; g.textBaseline = 'alphabetic'; g.fillStyle = '#323e4e';
      g.font = 'bold 34px Arial'; g.fillText(o.titel || 'Grundstück', ox, fy);
      g.font = '24px Arial'; g.fillText([o.untertitel, PARZ ? `Parzelle ${PARZ.number}` : ''].filter(Boolean).join(' · '), ox, fy + 34);
      g.font = '18px Arial'; g.fillStyle = '#6b7079';
      g.fillText(`Massstab 1:${f.m} · ${h.querySelector('[data-blatt]').selectedOptions[0].text} · erstellt ${new Date().toLocaleDateString('de-CH')} · Knechtgarten`, ox, fy + 64);
      g.fillText(`Quellen: swisstopo (Luftbild, Landeskarte, swissALTI3D ±0.25 m), amtliche Vermessung (geodienste.ch). Nicht rechtsverbindlich.`, ox, fy + 90);
      const sx = ox + MW - SB * s, sy = fy + 40; g.fillStyle = '#323e4e'; g.fillRect(sx, sy, SB * s / 2, 10); g.strokeStyle = '#323e4e'; g.lineWidth = 2; g.strokeRect(sx, sy, SB * s, 10);
      g.font = '18px Arial'; g.textAlign = 'center'; [0, SB / 2, SB].forEach(v => g.fillText(v + (v === SB ? ' m' : ''), sx + v * s, sy - 8));
      const d = new window.jspdf.jsPDF({ unit: 'mm', format: [f.W, f.H].sort((a, b) => a - b), orientation: f.W > f.H ? 'landscape' : 'portrait' });
      d.addImage(c.toDataURL('image/jpeg', 0.9), 'JPEG', 0, 0, f.W, f.H);
      d.save(`Plan ${o.titel || 'Grundstück'} 1-${f.m}`.replace(/[\\/:*?"<>|]/g, '') + '.pdf');
    }
    const taste = e => { if(e.key === 'Escape'){ if(punkte.length){ punkte = []; if(live) gruppe.removeLayer(live); labels.forEach(l => gruppe.removeLayer(l)); live = null; labels = []; } else zu(); }
      if(e.key === 'Backspace' && punkte.length && !/INPUT|TEXTAREA/.test(document.activeElement?.tagName)){ e.preventDefault(); punkte.pop(); zeichneLive(); } };
    const zu = () => { document.removeEventListener('keydown', taste, true); map.remove(); h.remove(); };
    document.addEventListener('keydown', taste, true);
    h.querySelector('[data-zu]').onclick = zu;
    return { map, zu };
  }

  const CSS = `
.kgk-vor{position:relative;display:block;width:100%;aspect-ratio:100/62;border-radius:8px;overflow:hidden;background:#e6e8eb;cursor:pointer}
.kgk-vor img,.kgk-vor svg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}
.kgk-vor i{position:absolute;left:50%;top:50%;width:10px;height:10px;margin:-5px 0 0 -5px;border-radius:50%;background:#323e4e;border:2px solid #fff}
.kgk-ovl{position:fixed;inset:0;z-index:300;background:rgba(35,43,53,.45);display:flex;align-items:center;justify-content:center;padding:16px;font-family:inherit}
.kgk-fen{width:min(1240px,100%);height:min(820px,100%);background:#fff;border-radius:14px;overflow:hidden;display:flex;box-shadow:0 20px 60px rgba(0,0,0,.3)}
.kgk-menu{width:230px;flex:none;overflow:auto;padding:14px;display:flex;flex-direction:column;gap:5px;font-size:12.5px;border-right:1px solid #e1e5e9}
.kgk-menu>b{color:#323e4e;font-size:11px;text-transform:uppercase;letter-spacing:.05em;margin-top:10px}
.kgk-menu label{display:flex;gap:6px;align-items:center}.kgk-dk input{flex:1;min-width:0}
.kgk-t{display:flex;flex-direction:column;gap:2px}.kgk-t b{color:#323e4e;font-size:14px}.kgk-t small{color:#6b7079;font-size:11.5px}
.kgk-werk{display:flex;flex-direction:column;gap:5px}
.kgk-werk button,.kgk-knopf{all:unset;box-sizing:border-box;cursor:pointer;font-size:12.5px;font-weight:600;border:1px solid #d5dbe1;background:#fff;color:#4c5c70;border-radius:8px;padding:6px 10px;text-align:left}
.kgk-werk button[aria-pressed=true],.kgk-knopf.an{background:#323e4e;border-color:#323e4e;color:#fff}
.kgk-ext{font-size:12.5px;color:#323e4e;font-weight:600;margin-top:12px}
.kgk-info{color:#6b7079;font-size:11.5px}
.kgk-rechts{flex:1;min-width:0;position:relative;display:flex;flex-direction:column}
.kgk-karte{flex:1;min-height:240px}
.kgk-zu{position:absolute;top:10px;right:10px;z-index:600;width:30px;height:30px}
.kgk-status{display:flex;gap:16px;flex-wrap:wrap;padding:5px 12px;font-size:12px;color:#323e4e;font-variant-numeric:tabular-nums;min-height:16px;border-top:1px solid #e1e5e9}
.kgk-ko{background:none;border:0}.kgk-ko i{position:absolute;width:5px;height:5px;margin:-2.5px 0 0 -2.5px;border-radius:50%;background:#ffe14d;border:1px solid #000}
.kgk-ko span{position:absolute;left:4px;top:-14px;white-space:nowrap;font-size:10px;font-weight:600;color:#000;text-shadow:0 0 2px #fff,0 0 2px #fff,0 0 3px #fff}
.kgk-rahmen{border:2px dashed #ff7a00;background:rgba(255,122,0,.06);cursor:move}
@media (max-width:760px){.kgk-fen{flex-direction:column}.kgk-menu{width:auto;max-height:38%;border-right:0;border-bottom:1px solid #e1e5e9}}
.kgk-lab{background:none;border:0}.kgk-lab span{display:inline-block;transform:translate(-50%,-50%);white-space:nowrap;background:rgba(255,255,255,.92);border:1px solid #ff7a00;color:#7a3a00;border-radius:5px;padding:1px 5px;font-size:11.5px;font-weight:600}
.kgk-lab.tot span{background:#ff7a00;color:#fff;font-size:12.5px}
.kgk-nr{background:none;border:0}.kgk-nr span{display:inline-block;transform:translate(-50%,-50%);font-size:13px;font-weight:600;white-space:nowrap}
.kgk-nr.hell span{color:#fff;text-shadow:0 0 3px #000,0 0 2px #000}.kgk-nr.dunkel span{color:#323e4e;text-shadow:0 0 3px #fff,0 0 2px #fff}
`;
  window.KGK = { laden, koordinaten, vorschau, oeffnen, hoehenGitter, zuWgs, zuLv };
})();
