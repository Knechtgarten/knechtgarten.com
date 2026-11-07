/* ============================================================================
   kg-plan.js – gemeinsamer Zeichen-Baustein für Pläne (SVG, Meter)
   Zuerst für den Pool-Konfigurator (Grundriss, Schnitt), später Grundlage fürs CAD
   (Situationsplan, Masskette, Schnitt). Alles in Metern, gezeichnet wird in SVG-Einheiten.
     const m = KGP.massstab(breiteM, hoeheM, W, H, { rand: 60, oben: 10 })  → { s, ox, oy, X(m), Y(m) }
     KGP.text(x, y, 'Länge', { fs, c, a, w, rot })      Text (rot = senkrecht)
     KGP.mass(x1, y1, x2, y2, '8.00 m', senkrecht)       Masslinie mit Endstrichen
     KGP.raster(m, W, H, 1)                              Raster (1 m) als <defs> + Fläche
     KGP.punkt(svg, event)                               Mauspunkt in SVG-Einheiten
     KGP.mm(8) → "8'000"   KGP.m(8) → "8.00"
   ============================================================================ */
(function(){
  const LINIE = '#8B9097', SCHRIFT = '#4C5C70';
  const KGP = {
    m: v => Number(v).toFixed(2),
    mm: v => String(Math.round(v * 1000)).replace(/\B(?=(\d{3})+(?!\d))/g, "'"),
    massstab(breite, hoehe, W, H, o = {}){
      const rand = o.rand ?? 50, oben = o.oben ?? 0;
      const s = Math.min((W - 2 * rand) / breite, (H - 2 * rand) / hoehe);
      const ox = (W - breite * s) / 2 + (o.dx || 0), oy = (H - hoehe * s) / 2 + oben;
      return { s, ox, oy, X: x => ox + x * s, Y: y => oy + y * s };
    },
    text(x, y, t, o = {}){
      return `<text x="${x}" y="${y}" font-size="${o.fs || 11}" fill="${o.c || SCHRIFT}" text-anchor="${o.a || 'middle'}" font-weight="${o.w || 400}"`
        + `${o.rot ? ` transform="rotate(-90 ${x} ${y})"` : ''} font-family="-apple-system,Segoe UI,Arial,sans-serif">${t}</text>`;
    },
    mass(x1, y1, x2, y2, t, senkrecht){
      const k = (x, y) => senkrecht ? `<path d="M${x - 4} ${y}h8" stroke="${LINIE}"/>` : `<path d="M${x} ${y - 4}v8" stroke="${LINIE}"/>`;
      const mx = (x1 + x2) / 2, my = (y1 + y2) / 2;
      return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${LINIE}"/>${k(x1, y1)}${k(x2, y2)}`
        + (senkrecht ? KGP.text(mx - 7, my, t, { rot: 1, w: 600 }) : KGP.text(mx, my - 6, t, { w: 600 }));
    },
    raster(m, W, H, schritt = 1, id = 'kgpRaster'){
      const g = m.s * schritt;
      return `<defs><pattern id="${id}" width="${g}" height="${g}" patternUnits="userSpaceOnUse" x="${m.ox}" y="${m.oy}"><path d="M${g} 0H0V${g}" fill="none" stroke="#EEF3F7"/></pattern></defs>`
        + `<rect width="${W}" height="${H}" fill="url(#${id})"/>`;
    },
    punkt(svg, e){
      const p = svg.createSVGPoint(); p.x = e.clientX; p.y = e.clientY;
      return p.matrixTransform(svg.getScreenCTM().inverse());
    }
  };
  window.KGP = KGP;
})();
