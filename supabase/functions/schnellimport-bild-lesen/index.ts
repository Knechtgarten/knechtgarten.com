// ============================================================================
// Offertentool 2027 - Schnellimport: liest ein eingefuegtes Bild (Screenshot/
// Foto einer Preisliste, E-Mail o.ae.) per Google Gemini aus und gibt die
// darin erkannten Artikel (Bezeichnung/Artikelnummer/Preise) als JSON zurueck.
//
// Bewusst NUR Text-/Preiserkennung, keine automatische Foto-Zuordnung - das
// Produktfoto wird im Frontend separat pro Artikel von Hand hochgeladen
// (siehe app/einstellungen-live-v1.html, Karte "Schnellimport").
//
// Erwartet KEIN bestimmtes Layout (anders als die Shop-Crawling-Functions,
// die einen fest bekannten HTML-Aufbau parsen) - das Bild kann von einer
// beliebigen Lieferanten-Webseite, E-Mail oder einem Katalog stammen, darum
// uebernimmt eine KI (statt fester Regeln) das Verstehen/Zerlegen.
//
// Aufruf vom Client: sb.functions.invoke('schnellimport-bild-lesen', { body: { bild_data_url } })
// bild_data_url = kompletter data:-URL-String (z.B. aus FileReader.readAsDataURL),
// inkl. "data:image/png;base64,..."-Praefix.
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

function parseZahl(text: unknown): number | null {
  if (text === null || text === undefined || text === '') return null;
  let s = String(text).trim().replace(/['\s]/g, '').replace(/CHF|EUR|€/gi, '');
  if (/,\d{1,2}$/.test(s)) s = s.replace(/\./g, '').replace(',', '.');
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}

// Gemini antwortet manchmal trotz Anweisung mit umgebendem Markdown
// (```json ... ```) oder erklaerendem Text davor/danach - robust nur den
// eigentlichen JSON-Array-Teil herausschneiden statt direkt JSON.parse() auf
// die komplette Antwort loszulassen.
function extrahiereJsonArray(text: string): unknown[] {
  const start = text.indexOf('[');
  const ende = text.lastIndexOf(']');
  if (start === -1 || ende === -1 || ende < start) throw new Error('Kein JSON-Array in der Antwort gefunden.');
  return JSON.parse(text.slice(start, ende + 1));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { bild_data_url } = await req.json().catch(() => ({}));
    if (!bild_data_url || typeof bild_data_url !== 'string') {
      return json({ error: 'bild_data_url ist erforderlich.' }, 400);
    }

    const match = bild_data_url.match(/^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/);
    if (!match) {
      return json({ error: 'bild_data_url hat kein erkennbares Bild-Format.' }, 400);
    }
    const [, mimeType, base64Daten] = match;

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      return json({ error: 'GEMINI_API_KEY ist serverseitig nicht hinterlegt. Bitte als Supabase Edge Function Secret eintragen.' }, 400);
    }

    const prompt = `Auf diesem Bild sind ein oder mehrere Verkaufs-/Preislisten-Artikel zu sehen (Screenshot einer Webseite, E-Mail oder Preisliste).
Erkenne fuer JEDEN einzelnen Artikel: die Bezeichnung, die Artikelnummer, den Einkaufspreis (das ist meist der guenstigere/reduzierte Preis, z.B. bei "Kommission"/Netto-/Haendlerpreis) und den Verkaufspreis (der hoehere/durchgestrichene oder normale Listenpreis, falls vorhanden).
Antworte AUSSCHLIESSLICH mit einem JSON-Array, keine Erklaerung, kein Markdown-Codeblock. Jedes Element als Objekt mit genau diesen Feldern:
{"bezeichnung": string, "artikelnummer": string oder null, "ek_preis": number oder null, "vp_preis": number oder null}
Zahlen als reine Zahl ohne Waehrungszeichen (z.B. 36.25, nicht "CHF 36.25"). Wenn kein Artikel erkennbar ist, gib ein leeres Array [] zurueck.`;

    const geminiRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [
              { text: prompt },
              { inline_data: { mime_type: mimeType, data: base64Daten } },
            ],
          }],
        }),
      },
    );

    if (!geminiRes.ok) {
      const fehlerText = await geminiRes.text().catch(() => '');
      return json({ error: `Gemini-Anfrage fehlgeschlagen (Status ${geminiRes.status}). ${fehlerText.slice(0, 300)}` }, 400);
    }

    const geminiJson = await geminiRes.json();
    const antwortText = geminiJson?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (!antwortText) {
      return json({ error: 'Gemini hat keine verwertbare Antwort geliefert.' }, 400);
    }

    let roheArtikel: any[];
    try {
      roheArtikel = extrahiereJsonArray(antwortText);
    } catch (_e) {
      return json({ error: 'Antwort von Gemini konnte nicht als Artikelliste gelesen werden.' }, 400);
    }

    const artikel = roheArtikel.map((a) => ({
      bezeichnung: String(a?.bezeichnung ?? '').trim(),
      artikelnummer: a?.artikelnummer ? String(a.artikelnummer).trim() : null,
      ek_preis: parseZahl(a?.ek_preis),
      vp_preis: parseZahl(a?.vp_preis),
    })).filter((a) => a.bezeichnung);

    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
