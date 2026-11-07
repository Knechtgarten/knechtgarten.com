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

  async function oeffnen(o){
    await laden();
    if(!o.e && o.adresse){ const p = await koordinaten(o.adresse); if(!p) throw new Error('Adresse nicht gefunden.'); Object.assign(o, p); }
    const [lon, lat] = zuWgs(o.e, o.n);
    css();
    const h = document.createElement('div'); h.className = 'kgk-ovl';
    h.innerHTML = `<div class="kgk-kopf"><div class="kgk-t"><b>${esc(o.titel || 'Grundstück')}</b><small>${esc(o.untertitel || '')}</small></div>
        <div class="kgk-werk" role="group" aria-label="Werkzeug"><button type="button" data-w="pan" aria-pressed="true">Verschieben</button><button type="button" data-w="strecke" aria-pressed="false">Strecke messen</button><button type="button" data-w="flaeche" aria-pressed="false">Fläche messen</button><button type="button" data-w="weg">Messungen löschen</button></div>
        <a class="kgk-ext" target="_blank" rel="noopener" href="https://www.topo.apps.be.ch/pub/map/?lang=de&center=${o.e},${o.n}&zoom=12">Im Geoportal Bern öffnen</a>
        <button type="button" class="kg-ibtn" data-zu aria-label="Schliessen">${window.KG && KG.icon ? KG.icon('x', 14) : '×'}</button></div>
      <div class="kgk-karte"></div>
      <div class="kgk-ebenen"><b>Hintergrund</b>
        ${[['luft', 'Luftbild'], ['farbe', 'Landeskarte'], ['grau', 'Landeskarte grau'], ['weiss', 'Keiner']].map(([k, t], i) => `<label><input type="radio" name="kgk-bg" value="${k}"${i ? '' : ' checked'}> ${t}</label>`).join('')}
        <label class="kgk-dk">Deckkraft <input type="range" min="10" max="100" value="100" data-dk></label>
        <b>Darüber</b>
        <label><input type="checkbox" data-av checked> Grenzen &amp; Gebäude</label>
        <label><input type="checkbox" data-hl> Höhenlinien (swisstopo)</label>
        <span class="kgk-info" data-info></span></div>
      <div class="kgk-status"><span data-hoehe>Höhe: Höhenlinien einschalten</span><span data-mess></span></div>`;
    document.body.appendChild(h);
    const map = L.map(h.querySelector('.kgk-karte'), { zoomControl: true, maxZoom: 22, doubleClickZoom: false }).setView([lat, lon], 20);
    const wmts = (l, f, max) => L.tileLayer(`https://wmts.geo.admin.ch/1.0.0/${l}/default/current/3857/{z}/{x}/{y}.${f}`, { maxNativeZoom: max, maxZoom: 22, attribution: '© swisstopo' });
    const BG = { luft: wmts('ch.swisstopo.swissimage', 'jpeg', 20), farbe: wmts('ch.swisstopo.pixelkarte-farbe', 'jpeg', 18), grau: wmts('ch.swisstopo.pixelkarte-grau', 'jpeg', 18), weiss: null };
    let bg = BG.luft; bg.addTo(map);
    // Amtliche Vermessung als Linien (geodienste.ch, WFS): Grenzen, Gebäude, Parzellennummern – durchsichtig über jedem Hintergrund
    const av = L.layerGroup().addTo(map); let avT = null, avNr = 0;
    const avFarbe = () => bg === BG.luft ? { g: '#ffe14d', h: '#ffb3c0', t: 'hell' } : { g: '#232b35', h: '#9a6b6b', t: 'dunkel' };
    const avLaden = async () => {
      av.clearLayers(); if(!map.hasLayer(av) || map.getZoom() < 17) return;
      const b = map.getBounds(), [x0, y0] = zuLv(b.getWest(), b.getSouth()), [x1, y1] = zuLv(b.getEast(), b.getNorth()), nr = ++avNr;
      const wfs = async t => (await (await fetch(`https://geodienste.ch/db/av_0/deu?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature&TYPENAMES=ms:${t}&BBOX=${x0},${y0},${x1},${y1},urn:ogc:def:crs:EPSG::2056&OUTPUTFORMAT=geojson&SRSNAME=urn:ogc:def:crs:EPSG::2056`)).json()).features || [];
      const [RESF, LCSF, OSNR] = await Promise.all(['RESF', 'LCSF', 'OSNR'].map(t => wfs(t).catch(() => [])));
      if(nr !== avNr) return; av.clearLayers();
      const f = avFarbe(), wg = ring => ring.map(p => zuWgs(p[0], p[1]).reverse());
      const ringe = x => x.geometry?.type === 'Polygon' ? x.geometry.coordinates : x.geometry?.type === 'MultiPolygon' ? x.geometry.coordinates.flat() : [];
      LCSF.filter(x => x.properties.Art === 'Gebaeude').forEach(x => av.addLayer(L.polygon(ringe(x).map(wg), { color: f.h, weight: 1.5, fill: f.t === 'dunkel', fillColor: '#f4dada', fillOpacity: .6, interactive: false })));
      RESF.forEach(x => av.addLayer(L.polygon(ringe(x).map(wg), { color: f.g, weight: 1.8, fill: false, interactive: false })));
      OSNR.forEach(x => { const [e, n] = x.geometry.coordinates; av.addLayer(L.marker(zuWgs(e, n).reverse(), { interactive: false, icon: L.divIcon({ className: 'kgk-nr ' + f.t, html: `<span>${esc(x.properties.Nummer)}</span>`, iconSize: null }) })); });
    };
    map.on('moveend', () => { clearTimeout(avT); avT = setTimeout(avLaden, 250); });
    avLaden();
    L.circleMarker([lat, lon], { radius: 5, color: '#fff', weight: 2, fillColor: '#323e4e', fillOpacity: 1 }).addTo(map);
    // eigene Parzelle hervorheben
    fetch(`${GEO}/api/MapServer/identify?geometry=${lon},${lat}&geometryType=esriGeometryPoint&sr=4326&layers=all:ch.kantone.cadastralwebmap-farbe&tolerance=0&returnGeometry=true&geometryFormat=geojson&imageDisplay=500,500,96&mapExtent=${lon - 0.001},${lat - 0.001},${lon + 0.001},${lat + 0.001}`)
      .then(r => r.json()).then(d => { const f = d.results?.[0]; if(!f) return;
        L.geoJSON(f.geometry, { style: { color: '#d1db5f', weight: 3, fill: false }, interactive: false }).addTo(map);
        h.querySelector('[data-info]').textContent = `Parzelle ${f.properties.number}${f.properties.egris_egrid ? ' · ' + f.properties.egris_egrid : ''}`; }).catch(() => {});
    setTimeout(() => map.invalidateSize(), 50);

    // Hintergrund, Deckkraft, Ebenen
    let dk = 1;
    h.querySelectorAll('[name="kgk-bg"]').forEach(r => r.onchange = () => { if(bg) map.removeLayer(bg); bg = BG[r.value]; if(bg){ bg.setOpacity(dk); bg.addTo(map); bg.bringToBack(); } avLaden(); });
    h.querySelector('[data-dk]').oninput = e => { dk = e.target.value / 100; if(bg) bg.setOpacity(dk); };
    h.querySelector('[data-av]').onchange = e => { if(e.target.checked){ av.addTo(map); avLaden(); } else map.removeLayer(av); };
    let HL = null, gitter = null;
    const hlLaden = async () => {
      const b = map.getBounds(), [x0, y0] = zuLv(b.getWest(), b.getSouth()), [x1, y1] = zuLv(b.getEast(), b.getNorth());
      const info = h.querySelector('[data-info]');
      if(x1 - x0 > 400 || y1 - y0 > 400){ info.textContent = 'Für Höhenlinien näher heranzoomen.'; return; }
      info.textContent = 'Höhen werden geladen …';
      try {
        gitter = await hoehenGitter(x0 - 10, y0 - 10, x1 + 10, y1 + 10);
        const flach = Math.max(x1 - x0, y1 - y0) < 120, stufe = flach ? 0.25 : 0.5, { out, zmin, zmax } = gitter.linien(stufe);
        if(HL) map.removeLayer(HL); HL = L.layerGroup();
        out.forEach(l => { const meter = Math.abs(l.hoehe - Math.round(l.hoehe)) < 1e-6;
          const lat_ = l.seg.map(([p, q]) => [zuWgs(p[0], p[1]).reverse(), zuWgs(q[0], q[1]).reverse()]);
          L.polyline(lat_, { color: meter ? '#8a5a1e' : '#c99a5a', weight: meter ? 2 : 1, opacity: .9, interactive: false }).addTo(HL); });
        HL.addTo(map);
        info.textContent = `Höhenlinien alle ${stufe} m · ${zmin.toFixed(1)}–${zmax.toFixed(1)} m ü. M. · swissALTI3D ${gitter.jahr}, ca. ±0.25 m`;
      } catch(err){ info.textContent = 'Höhen nicht verfügbar: ' + err.message; }
    };
    h.querySelector('[data-hl]').onchange = e => { if(e.target.checked) hlLaden(); else { if(HL) map.removeLayer(HL); HL = null; gitter = null; h.querySelector('[data-info]').textContent = ''; h.querySelector('[data-hoehe]').textContent = 'Höhe: Höhenlinien einschalten'; } };
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
    const fertig = () => { if(werkzeug === 'flaeche' && punkte.length > 2){ if(live) gruppe.removeLayer(live); labels.forEach(l => gruppe.removeLayer(l)); labels = [];
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
    const setW = w => { if(w === 'weg'){ gruppe.clearLayers(); punkte = []; live = null; labels = []; h.querySelector('[data-mess]').textContent = ''; return; }
      fertig(); werkzeug = w; h.querySelectorAll('[data-w]').forEach(b => b.dataset.w !== 'weg' && b.setAttribute('aria-pressed', String(b.dataset.w === w)));
      h.querySelector('.kgk-karte').style.cursor = w === 'pan' ? '' : 'crosshair'; };
    h.querySelectorAll('[data-w]').forEach(b => b.onclick = () => setW(b.dataset.w));
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
.kgk-ovl{position:fixed;inset:0;z-index:300;background:#f5f7f9;display:flex;flex-direction:column;font-family:inherit}
.kgk-kopf{display:flex;flex-wrap:wrap;gap:10px;align-items:center;padding:10px 16px;background:#fff;border-bottom:1px solid #e1e5e9}
.kgk-t{display:flex;flex-direction:column;flex:1 1 220px;min-width:0}.kgk-t b{color:#323e4e;font-size:15px}.kgk-t small{color:#6b7079;font-size:12px}
.kgk-werk{display:flex;flex-wrap:wrap;gap:6px}
.kgk-werk button{all:unset;cursor:pointer;font-size:12.5px;font-weight:600;border:1px solid #d5dbe1;background:#fff;color:#4c5c70;border-radius:99px;padding:6px 12px}
.kgk-werk button[aria-pressed=true]{background:#323e4e;border-color:#323e4e;color:#fff}
.kgk-ext{font-size:12.5px;color:#323e4e;font-weight:600}
.kgk-karte{flex:1;min-height:280px}
.kgk-ebenen{position:absolute;left:16px;top:84px;z-index:500;background:#fff;border:1px solid #e1e5e9;border-radius:10px;padding:10px 12px;display:flex;flex-direction:column;gap:5px;font-size:12.5px;box-shadow:0 4px 14px rgba(0,0,0,.12);max-width:240px}
.kgk-ebenen b{color:#323e4e;font-size:11px;text-transform:uppercase;letter-spacing:.05em;margin-top:4px}
.kgk-ebenen label{display:flex;gap:6px;align-items:center}.kgk-dk input{flex:1;min-width:0}
.kgk-info{color:#6b7079;font-size:11.5px}
.kgk-status{display:flex;gap:16px;flex-wrap:wrap;padding:6px 16px;background:#fff;border-top:1px solid #e1e5e9;font-size:12.5px;color:#323e4e;font-variant-numeric:tabular-nums}
.kgk-lab{background:none;border:0}.kgk-lab span{display:inline-block;transform:translate(-50%,-50%);white-space:nowrap;background:rgba(255,255,255,.92);border:1px solid #ff7a00;color:#7a3a00;border-radius:5px;padding:1px 5px;font-size:11.5px;font-weight:600}
.kgk-lab.tot span{background:#ff7a00;color:#fff;font-size:12.5px}
.kgk-nr{background:none;border:0}.kgk-nr span{display:inline-block;transform:translate(-50%,-50%);font-size:13px;font-weight:600;white-space:nowrap}
.kgk-nr.hell span{color:#fff;text-shadow:0 0 3px #000,0 0 2px #000}.kgk-nr.dunkel span{color:#323e4e;text-shadow:0 0 3px #fff,0 0 2px #fff}
@media (max-width:700px){.kgk-ebenen{top:auto;bottom:44px;left:8px;max-width:200px}}
`;
  window.KGK = { laden, koordinaten, vorschau, oeffnen, hoehenGitter, zuWgs, zuLv };
})();
