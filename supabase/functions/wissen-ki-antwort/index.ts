// ============================================================================
// wissen-ki-antwort – KI-Antwort für die Suche im Nachschlagewerk.
// Das Tool schickt die Frage und die passendsten Einträge (Text, schon vom Tool
// zusammengestellt). Claude antwortet NUR aus diesen Einträgen, kurz und auf
// Schweizerdeutsch-Schriftsprache (ss statt ß). Steht nichts dazu drin, sagt es
// das ehrlich, statt zu raten. Nur für eingeloggte Benutzer (verify_jwt).
// ============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

// schnell und günstig; fällt auf das ältere Modell zurück, falls das neue (noch) nicht verfügbar ist
const MODELLE = ['claude-haiku-5-5', 'claude-haiku-4-5-20251001'];

const SYSTEM = `Du beantwortest Fragen von Mitarbeitenden der Gartenbaufirma Knechtgarten (Heimenschwand, Schweiz) aus ihrem internen Nachschlagewerk.
Regeln:
- Antworte NUR mit dem, was in den mitgeschickten Einträgen steht. Erfinde nichts und ergänze kein Allgemeinwissen.
- Steht zur Frage nichts Passendes in den Einträgen, setze "gefunden" auf false und sage in einem Satz, dass dazu noch nichts im Nachschlagewerk steht.
- Schreibe kurz und klar auf Deutsch (Schweizer Rechtschreibung, ss statt ß). Höchstens 5 Zeilen.
- Zuerst ein Satz mit der direkten Antwort, danach falls hilfreich eine kurze Liste mit Zeilen, die mit "- " beginnen. Wichtige Zahlen oder Begriffe mit **doppelten Sternen** fett.
- "quellen" enthält die ids der Einträge, aus denen die Antwort stammt (nur diese).
Gib ausschliesslich JSON zurück: {"gefunden": true|false, "antwort": "...", "quellen": ["id", ...]}`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Nur POST.' }, 405);
  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Ungültige Anfrage.' }, 400); }
  const frage = String(body?.frage || '').trim().slice(0, 500);
  const eintraege = Array.isArray(body?.eintraege) ? body.eintraege.slice(0, 10) : [];
  if (!frage) return json({ error: 'Frage fehlt.' }, 400);
  if (!eintraege.length) return json({ gefunden: false, antwort: 'Dazu steht noch nichts im Nachschlagewerk.', quellen: [] });

  const kontext = eintraege.map((e: any) =>
    `<eintrag id="${String(e.id).slice(0, 64)}">\nTitel: ${String(e.titel || '').slice(0, 200)}\n${String(e.text || '').slice(0, 6000)}\n</eintrag>`).join('\n\n');

  let letzterFehler = '';
  for (const model of MODELLE) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({
        model, max_tokens: 700, system: SYSTEM,
        messages: [{ role: 'user', content: `Einträge aus dem Nachschlagewerk:\n\n${kontext}\n\nFrage: ${frage}` }],
      }),
    });
    const data = await res.json();
    if (!res.ok) { letzterFehler = data?.error?.message || `Anthropic-Fehler (${res.status})`; continue; }
    const text = (data.content || []).filter((c: any) => c.type === 'text').map((c: any) => c.text).join('');
    const m = text.match(/\{[\s\S]*\}/);
    try {
      const r = JSON.parse(m ? m[0] : text);
      const ids = new Set(eintraege.map((e: any) => String(e.id)));
      return json({ gefunden: !!r.gefunden, antwort: String(r.antwort || ''), quellen: (r.quellen || []).map(String).filter((i: string) => ids.has(i)), modell: model });
    } catch {
      return json({ gefunden: true, antwort: text.trim(), quellen: [], modell: model });
    }
  }
  return json({ error: letzterFehler || 'KI nicht erreichbar.' }, 502);
});
