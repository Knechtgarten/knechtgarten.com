// ============================================================================
// Offertentool 2027 - Freitext-Rechner: liest eine eingefuegte Fremdofferte/
// Preisliste (Screenshot, Foto, PDF-Ausschnitt) per Google Gemini aus und
// gibt die darin erkannten Positionen (Menge/Bezeichnung/Preis) als JSON
// zurueck - genutzt vom "Preis zusammenrechnen"-Popup bei Freitext-/Eigenen
// Positionen in Tool A (app/tool-a-live-v1.html), wenn eine Position aus
// mehreren Fremdleistungs-Posten besteht (z.B. Beckenkoerper + Fracht eines
// externen Lieferanten, kein Artikel im eigenen Artikelstamm).
//
// Anders als schnellimport-bild-lesen (Artikelstamm-Pflege: Bezeichnung/
// Artikelnummer/EK-/VP-Preis) reicht hier pro Position nur Menge/Bezeichnung/
// Einzelpreis - es gibt keinen Artikelstamm-Abgleich, die erkannten Zeilen
// sind reine Rechenhilfe innerhalb des Popups (nicht persistiert).
//
// Aufruf vom Client: sb.functions.invoke('freitext-rechner-bild-lesen', { body: { bild_data_url } })
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
// eigentlichen JSON-Objekt-Teil herausschneiden statt direkt JSON.parse() auf
// die komplette Antwort loszulassen.
function extrahiereJsonObjekt(text: string): Record<string, unknown> {
  const start = text.indexOf('{');
  const ende = text.lastIndexOf('}');
  if (start === -1 || ende === -1 || ende < start) throw new Error('Kein JSON-Objekt in der Antwort gefunden.');
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

    const prompt = `Auf diesem Bild ist eine Fremdofferte, Preisliste oder Rechnung eines externen Lieferanten zu sehen (nicht der eigene Artikelstamm).
Erkenne zuerst die verwendete Waehrung (am Waehrungszeichen/-code wie "CHF", "€"/"EUR", "$"/"USD" etc. erkennbar - meist bei allen Preisen gleich). Falls nicht eindeutig erkennbar, gib null zurueck.
Erkenne dann fuer JEDE einzelne Position: die Menge, die Bezeichnung/Beschreibung und den Preis. Der Preis ist der EINZELPREIS pro Stueck/Einheit, falls sowohl Einzel- als auch Gesamtpreis pro Zeile sichtbar sind - nimm im Zweifel den Einzelpreis. Fehlt eine Mengenangabe, nimm 1 an.
Antworte AUSSCHLIESSLICH mit einem einzigen JSON-Objekt, keine Erklaerung, kein Markdown-Codeblock, genau diese Form:
{"waehrung": "CHF" | "EUR" | "USD" | string | null, "positionen": [{"menge": number, "bezeichnung": string, "preis": number}, ...]}
Zahlen als reine Zahl ohne Waehrungszeichen (z.B. 620.5, nicht "CHF 620.50"). Summen-/Total-Zeilen NICHT als eigene Position aufnehmen. Wenn keine Position erkennbar ist, gib ein leeres Array bei "positionen" zurueck.`;

    // Google benennt/entfernt Gemini-Modelle immer wieder ohne Vorwarnung -
    // mehrere bekannte Kandidaten nacheinander durchprobieren, siehe gleiches
    // Muster in schnellimport-bild-lesen.
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
            contents: [{
              parts: [
                { text: prompt },
                { inline_data: { mime_type: mimeType, data: base64Daten } },
              ],
            }],
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
    if (!antwortText) {
      return json({ error: 'Gemini hat keine verwertbare Antwort geliefert.' }, 400);
    }

    let rohesObjekt: Record<string, unknown>;
    try {
      rohesObjekt = extrahiereJsonObjekt(antwortText);
    } catch (_e) {
      return json({ error: 'Antwort von Gemini konnte nicht als Positionsliste gelesen werden.' }, 400);
    }

    const rohePositionen = Array.isArray(rohesObjekt?.positionen) ? rohesObjekt.positionen as any[] : [];
    const positionen = rohePositionen.map((p) => ({
      menge: parseZahl(p?.menge) ?? 1,
      bezeichnung: String(p?.bezeichnung ?? '').trim(),
      preis: parseZahl(p?.preis) ?? 0,
    })).filter((p) => p.bezeichnung);

    const waehrungRoh = rohesObjekt?.waehrung;
    const waehrung = typeof waehrungRoh === 'string' && waehrungRoh.trim() ? waehrungRoh.trim().toUpperCase() : null;

    return json({ positionen, waehrung });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
