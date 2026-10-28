// ============================================================================
// Offertentool 2027 - Preisliste lesen: liest einen Ausschnitt (1-3 Seiten als
// PDF oder ein Bild) der Transport-Preisliste eines Kies-/Betonwerks per
// Google Gemini aus und gibt die erkannten Transportpreise als JSON zurueck.
//
//  * Ortsliste (Heimberg, Stucki, Daepp): Zeilen mit PLZ/Gemeinde/Ort, Preis pro m3
//    fuer Kies/Sand und fuer Beton, Zone.
//  * Distanzliste (Alluvia): Preis pro m3 je Kilometerstufe.
//
// Das Zerschneiden einer grossen PDF in kleine Ausschnitte und das Speichern
// passiert im Browser (Einstellungen -> Kies- und Betonwerke), diese Function
// liest nur EINEN Ausschnitt pro Aufruf (haelt jeden Aufruf kurz).
//
// Aufruf vom Client:
//   sb.functions.invoke('preisliste-lesen', { body: { datei_data_url, werk_name } })
// datei_data_url = data:-URL (application/pdf oder image/*) inkl. base64.
// Antwort: { typ: 'ort'|'distanz'|'keine', jahr, mindestmenge_kies, mindestmenge_beton, zeilen: [...], stufen: [...] }
// Benoetigt das Secret GEMINI_API_KEY (wie die Function "schnellimport-bild-lesen").
// ============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function zahl(v: unknown): number | null {
  if (v === null || v === undefined || v === '') return null;
  const s = String(v).trim().replace(/['\s]/g, '').replace(/CHF/gi, '').replace(',', '.');
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}
function text(v: unknown): string | null {
  const s = v === null || v === undefined ? '' : String(v).trim();
  return s ? s : null;
}

// Gemini antwortet manchmal mit Markdown-Zaun oder Text drumherum - nur das JSON-Objekt herausschneiden
function extrahiereJsonObjekt(t: string): any {
  const start = t.indexOf('{');
  const ende = t.lastIndexOf('}');
  if (start === -1 || ende === -1 || ende < start) throw new Error('Kein JSON-Objekt in der Antwort gefunden.');
  return JSON.parse(t.slice(start, ende + 1));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { datei_data_url, werk_name } = await req.json().catch(() => ({}));
    if (!datei_data_url || typeof datei_data_url !== 'string') {
      return json({ error: 'datei_data_url ist erforderlich.' }, 400);
    }
    const match = datei_data_url.match(/^data:((?:application\/pdf)|(?:image\/[a-zA-Z0-9.+-]+));base64,(.+)$/);
    if (!match) return json({ error: 'Die Datei muss ein PDF oder ein Bild sein.' }, 400);
    const [, mimeType, base64Daten] = match;

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return json({ error: 'GEMINI_API_KEY ist serverseitig nicht hinterlegt. Bitte als Supabase Edge Function Secret eintragen.' }, 400);
    }

    const prompt = `Das ist ein Ausschnitt (eine oder mehrere Seiten oder ein Foto) aus der Preisliste des Kies-/Betonwerks "${werk_name || 'unbekannt'}".
Lies NUR die TRANSPORTPREISE aus (Fuhrtarife, Transport franko Baustelle, Akkordtarife). KEINE Materialpreise, keine Betonsorten, keine Mietgeraete, keine Regie-/Stundentarife, keine Mulden.

Es gibt zwei moegliche Aufbauten:
A) Ortsliste: Zeilen mit Ortschaft (oft mit PLZ, Gemeinde oder Ortsteil), einem Preis pro m3 fuer "Kies und Sand" und einem Preis pro m3 fuer "Beton", evtl. mit Zone.
B) Distanzliste: Preise pro m3 (und evtl. pro Tonne) nach Kilometerstufen (z.B. "bis 5,0 km", "5,01 - 7,5 km").

Regeln:
- Nimm immer CHF pro m3, nie CHF pro Tonne.
- Spalte "Kies und Sand" (Kies/Sand/Kies/m3) -> kies. Spalte "Beton" -> beton.
- Stehen mehrere Werke nebeneinander in Spalten (z.B. "Kieswerk Daepp AG Oppligen" und "Hu. Liechti AG Schoepbach"), nimm nur die Spalten des Werks, das zu "${werk_name || ''}" passt (Daepp = Oppligen). Gibt es keine Spaltenaufteilung nach Werk, nimm die vorhandenen Preisspalten.
- Fehlt ein Preis, schreibe null. Zahlen mit Punkt (z.B. 20.80).
- Jede Ortszeile genau einmal, nichts weglassen, nichts erfinden. Bei einer Gliederung Gemeinde / Ort: "gemeinde" = Name der Gemeinde (steht oft nur in der ersten Zeile der Gruppe, wiederhole ihn fuer alle Zeilen der Gruppe), "ort" = Ortsteil oder Weiler (z.B. "Dorf"). Gibt es nur eine Ortsspalte mit PLZ, dann "plz" und "ort" fuellen und "gemeinde" null.
- Bei einer Distanzliste mit nur einer Preisspalte pro m3 gilt der Preis fuer Kies UND Beton (beide gleich setzen). "bis_km" ist die obere Grenze der Stufe: "bis 5,0 km" = 5, "5,01 - 7,5 km" = 7.5, "90,01 - 100,0 km" = 100.
- Falls im Ausschnitt genannt: Mindestmenge pro Fuhre in m3 fuer Kies und fuer Beton (z.B. "Mindesttransportmenge 8 m3 Kies bzw. 6 m3 Beton") und das Gueltigkeitsjahr der Liste.

Antworte AUSSCHLIESSLICH mit einem JSON-Objekt, kein Markdown, keine Erklaerung:
{"typ":"ort" oder "distanz" oder "keine","jahr":Zahl oder null,"mindestmenge_kies":Zahl oder null,"mindestmenge_beton":Zahl oder null,"zeilen":[{"plz":Text oder null,"gemeinde":Text oder null,"ort":Text,"kies":Zahl oder null,"beton":Zahl oder null,"zone":Text oder null}],"stufen":[{"bis_km":Zahl,"kies":Zahl oder null,"beton":Zahl oder null}]}
Enthaelt der Ausschnitt keine Transportpreise: typ "keine" und leere Listen.`;

    // Modellnamen wechseln bei Google gelegentlich - mehrere Kandidaten nacheinander probieren (wie schnellimport-bild-lesen)
    const MODELL_KANDIDATEN = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];
    let geminiRes: Response | null = null;
    let letzterFehler = '';
    for (const modell of MODELL_KANDIDATEN) {
      const res = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/${modell}:generateContent?key=${apiKey}`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }, { inline_data: { mime_type: mimeType, data: base64Daten } }] }],
            generationConfig: { temperature: 0, maxOutputTokens: 32768, responseMimeType: 'application/json' },
          }),
        },
      );
      if (res.ok) { geminiRes = res; break; }
      letzterFehler = `Modell "${modell}": Status ${res.status}. ${(await res.text().catch(() => '')).slice(0, 200)}`;
    }
    if (!geminiRes) {
      return json({ error: `Gemini-Anfrage fehlgeschlagen bei allen probierten Modellen. Letzter Fehler - ${letzterFehler}` }, 400);
    }

    const geminiJson = await geminiRes.json();
    const antwortText = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!antwortText) return json({ error: 'Gemini hat keine verwertbare Antwort geliefert.' }, 400);

    let roh: any;
    try {
      roh = extrahiereJsonObjekt(antwortText);
    } catch (_e) {
      return json({ error: 'Die Antwort von Gemini konnte nicht gelesen werden (vermutlich zu lang). Bitte weniger Seiten hineinziehen.' }, 400);
    }

    const typ = roh?.typ === 'ort' || roh?.typ === 'distanz' ? roh.typ : 'keine';
    const zeilen = (Array.isArray(roh?.zeilen) ? roh.zeilen : [])
      .map((z: any) => ({
        plz: text(z?.plz),
        gemeinde: text(z?.gemeinde),
        ort: text(z?.ort),
        kies: zahl(z?.kies),
        beton: zahl(z?.beton),
        zone: text(z?.zone),
      }))
      .filter((z: any) => (z.ort || z.gemeinde || z.plz) && (z.kies !== null || z.beton !== null));
    const stufen = (Array.isArray(roh?.stufen) ? roh.stufen : [])
      .map((s: any) => ({ bis_km: zahl(s?.bis_km), kies: zahl(s?.kies), beton: zahl(s?.beton) }))
      .filter((s: any) => s.bis_km !== null && (s.kies !== null || s.beton !== null));

    return json({
      typ,
      jahr: zahl(roh?.jahr),
      mindestmenge_kies: zahl(roh?.mindestmenge_kies),
      mindestmenge_beton: zahl(roh?.mindestmenge_beton),
      zeilen,
      stufen,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
