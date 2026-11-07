// Geodaten zu einem Grundstück (für «Bewilligungen»): aus Adresse oder Koordinaten (LV95)
//   - Koordinaten:   api3.geo.admin.ch SearchServer (Adresse → E/N)
//   - Grundstück:    ÖREB-Kataster Kanton Bern (getegrid + extract/json): Parzelle, EGRID, Fläche, betroffene und
//                    nicht betroffene Themen (Zone, Gewässerschutz, Grundwasserschutz, Lärmstufen, Wald, Naturgefahren …)
//   - Bund (identify): Bauzonen, seismische Baugrundklasse, Nachführungsgeometer, Grundbuchkreis
// Aufruf: { adresse: "Herrenwäldlirain 8, 3065 Bolligen" } oder { e, n }. Nur für angemeldete Benutzer (JWT).
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...CORS, 'Content-Type': 'application/json' } });
const GEO = 'https://api3.geo.admin.ch/rest/services';
const OEREB = 'https://www.oereb2.apps.be.ch';
const de = (t: any) => Array.isArray(t) ? (t.find((x: any) => x.Language === 'de')?.Text ?? t[0]?.Text ?? '') : (t ?? '');

async function identify(e: number, n: number, layer: string) {
  const u = `${GEO}/api/MapServer/identify?geometry=${e},${n}&geometryType=esriGeometryPoint&sr=2056&layers=all:${layer}&tolerance=0&returnGeometry=false&imageDisplay=500,500,96&mapExtent=${e - 50},${n - 50},${e + 50},${n + 50}&lang=de`;
  try { const r = await fetch(u); if (!r.ok) return null; const d = await r.json(); return d.results?.[0]?.attributes ?? null; } catch (_) { return null; }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const body = await req.json().catch(() => ({}));
    let e = Number(body.e) || 0, n = Number(body.n) || 0, adresseGefunden = '';
    if (!e && body.adresse) {
      const r = await (await fetch(`${GEO}/api/SearchServer?type=locations&origins=address&sr=2056&limit=1&searchText=${encodeURIComponent(body.adresse)}`)).json();
      const a = r.results?.[0]?.attrs;
      if (!a) return json({ error: 'Adresse nicht gefunden' }, 404);
      e = Math.round(a.y * 10) / 10; n = Math.round(a.x * 10) / 10; adresseGefunden = String(a.label || '').replace(/<[^>]+>/g, '');
    }
    if (!e || !n) return json({ error: 'Adresse oder Koordinaten fehlen' }, 400);

    const [bauzone, baugrund, geometer, grundbuch, kataster] = await Promise.all([
      identify(e, n, 'ch.are.bauzonen'), identify(e, n, 'ch.bafu.gefahren-baugrundklassen'),
      identify(e, n, 'ch.swisstopo-vd.geometa-nfgeom'), identify(e, n, 'ch.swisstopo-vd.geometa-grundbuch'),
      identify(e, n, 'ch.kantone.cadastralwebmap-farbe')]);

    const out: any = { e, n, adresse: adresseGefunden, kanton: kataster?.ak || null,
      parzelle: kataster?.number || null, egrid: kataster?.egris_egrid || null,
      bauzone: bauzone ? bauzone.ch_bez_d : null, baugrundklasse: baugrund ? baugrund.bgk : null,
      geometer: geometer ? { name: geometer.name, firma: geometer.firmenname, adresse: String(geometer.adresse || '').replace('#', ', '), telefon: geometer.telefon, email: geometer.email } : null,
      grundbuchkreis: grundbuch?.grundbuchkreis || null, oereb: null };

    // ÖREB Kanton Bern (amtlich): nur für Grundstücke im Kanton Bern
    if (out.kanton === 'BE' && out.egrid) {
      try {
        const x = (await (await fetch(`${OEREB}/extract/json?EGRID=${out.egrid}`)).json())?.GetExtractByIdResponse?.extract;
        const re = x?.RealEstate || {};
        const betroffen = (re.RestrictionOnLandownership || []).map((r: any) => ({ thema: de(r.Theme?.Text), legende: de(r.LegendText), anteil: r.PartInPercent ?? null, flaeche: r.AreaShare ?? null }));
        out.flaeche_m2 = re.LandRegistryArea ?? null;
        out.gemeinde = re.MunicipalityName || null;
        out.oereb = {
          betroffen, nicht_betroffen: (x?.NotConcernedTheme || []).map((t: any) => de(t.Text)),
          ohne_daten: (x?.ThemeWithoutData || []).map((t: any) => de(t.Text)),
          pdf: `${OEREB}/extract/pdf?EGRID=${out.egrid}`, stand: x?.UpdateDateCS || null,
        };
        const finde = (rx: RegExp) => betroffen.filter((b: any) => rx.test(b.thema)).map((b: any) => b.legende);
        out.zone = finde(/Zonenflächen der Grundnutzung/).join(', ') || null;
        out.gewaesserschutz = finde(/Gewässerschutzbereich/).join(', ') || null;
        out.grundwasserschutz = finde(/Grundwasserschutz/).join(', ') || null;
        out.laermstufe = finde(/Lärmempfindlichkeitsstufe/).join(', ') || null;
        out.gewaesserraum = finde(/Gewässerraum/).join(', ') || null;
        out.wald = finde(/Wald/).join(', ') || null;
        out.naturgefahren = finde(/Naturgefahren/).join(', ') || null;
        out.denkmal = finde(/Denkmal|Bauinventar|Archäolog/).join(', ') || null;
        out.belastet = finde(/belasteten Standorte/).join(', ') || null;
      } catch (err) { out.oereb_fehler = String(err); }
    }
    return json(out);
  } catch (err) {
    return json({ error: String((err as any)?.message || err) }, 500);
  }
});
