// ============================================================================
// Pendenzen-App (app/pendenzen-app.html): KI-Diktat. Nimmt eine Sprachaufnahme
// vom Handy entgegen und lässt sie von Google Gemini in zwei Formen schreiben:
//   wortlich – was gesagt wurde, möglichst wörtlich (Hochdeutsch, Mundart übertragen)
//   titel    – daraus eine kurze, saubere Pendenz (eine Zeile)
// Der wörtliche Text landet in der Notiz der Pendenz, damit nichts verloren geht.
//
// Aufruf: sb.functions.invoke('pendenz-diktat', { body: { audio_base64, mime_type } })
//   oder:  sb.functions.invoke('pendenz-diktat', { body: { text } })  – «Aufräumen»: diktierten/getippten Text zu einer kurzen Pendenz machen
// ============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

// Gemini antwortet manchmal mit Markdown um das JSON herum – nur den Objekt-Teil herausschneiden
function extrahiereJsonObjekt(text: string): Record<string, unknown> {
  const start = text.indexOf('{'), ende = text.lastIndexOf('}');
  if (start === -1 || ende < start) throw new Error('Kein JSON-Objekt in der Antwort gefunden.');
  return JSON.parse(text.slice(start, ende + 1));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { audio_base64, mime_type, text: eingabe } = await req.json().catch(() => ({}));
    const nurText = typeof eingabe === 'string' && eingabe.trim().length > 0;
    if (!nurText && (!audio_base64 || typeof audio_base64 !== 'string')) return json({ error: 'audio_base64 oder text ist erforderlich.' }, 400);
    // Browser liefern z. B. "audio/webm;codecs=opus" – Gemini will nur den Grundtyp
    const mime = String(mime_type || 'audio/webm').split(';')[0].trim();

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) return json({ error: 'GEMINI_API_KEY ist serverseitig nicht hinterlegt.' }, 400);

    const prompt = `Das ist eine kurze Sprachnotiz von Stefan oder einem Mitarbeiter von Knechtgarten, einem Gartenbauunternehmen in Heimenschwand (Kanton Bern, Schweiz).
Gesprochen wird Schweizer Hochdeutsch oder Berndeutsch, oft unterwegs (Auto, Baustelle), mit Füllwörtern und Neuanfängen.
Fachwörter aus Gartenbau, Bepflanzung, Schwimmteich, Poolbau, Bewässerung und Baustelle sind häufig (z. B. Quellstein, Schwimmteich, UVC, Rollrasen, Bagger, Offerte, AVOR, Rapport).
Gib zwei Dinge zurück:
1. "wortlich": was gesagt wurde, möglichst wörtlich, aber in Schweizer Hochdeutsch geschrieben (ss statt ß, Mundart ins Hochdeutsche übertragen), ohne Füllwörter wie "ähm".
2. "titel": daraus EINE kurze, klare Pendenz (max. ca. 12 Wörter), wie man sie auf eine Pendenzenliste schreibt, z. B. "Grunder: Quellsteine in Betrieb nehmen" oder "Offerte Müller nachfassen". Namen von Personen und Kunden beibehalten. Keine Erfindungen, nichts hinzufügen, was nicht gesagt wurde.
Wenn nichts Verständliches gesagt wurde, gib bei beiden einen leeren Text zurück.
Antworte AUSSCHLIESSLICH mit einem JSON-Objekt, ohne Markdown: {"wortlich": string, "titel": string}`;

    // Google benennt Modelle immer wieder um – mehrere Kandidaten durchprobieren (gleiches Muster wie preisliste-lesen)
    const MODELL_KANDIDATEN = ['gemini-flash-latest', 'gemini-2.5-flash', 'gemini-2.0-flash'];
    let antwort: Response | null = null, letzterFehler = '';
    for (const modell of MODELL_KANDIDATEN) {
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${modell}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents: [{ parts: nurText
            ? [{ text: prompt.replace('Das ist eine kurze Sprachnotiz', 'Das ist der Text einer kurzen Sprachnotiz (vom Handy direkt abgeschrieben, kann Fehler enthalten)') + '\n\nText: ' + eingabe.trim().slice(0, 4000) }]
            : [{ text: prompt }, { inline_data: { mime_type: mime, data: audio_base64 } }] }],
          generationConfig: { temperature: 0.2, responseMimeType: 'application/json' } }),
      });
      if (res.ok) { antwort = res; break; }
      letzterFehler = `Modell "${modell}": Status ${res.status}. ${(await res.text().catch(() => '')).slice(0, 200)}`;
    }
    if (!antwort) return json({ error: `Gemini-Anfrage fehlgeschlagen. ${letzterFehler}` }, 400);

    const daten = await antwort.json();
    const text = (daten?.candidates?.[0]?.content?.parts || []).map((p: any) => p?.text || '').join('');
    if (!text) return json({ error: 'Gemini hat keine verwertbare Antwort geliefert.' }, 400);
    let o: Record<string, unknown>;
    try { o = extrahiereJsonObjekt(text); } catch (_e) { return json({ error: 'Antwort von Gemini war kein lesbares JSON.' }, 400); }

    return json({ wortlich: String(o.wortlich ?? '').trim(), titel: String(o.titel ?? '').trim() });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
