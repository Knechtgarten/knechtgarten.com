// ============================================================================
// einsatzplaner-serie-ki – KI-Eingabe im Serientermin-Fenster des Einsatzplaners.
// Das Tool schickt den gesprochenen/geschriebenen Wunsch plus die Personen,
// Absenz-Arten und Icons. Claude füllt daraus die Felder des Fensters aus
// (eine oder mehrere Serien). Gespeichert wird nichts: der Benutzer prüft die
// Vorschau und klickt selber auf «Serie erstellen». Nur für eingeloggte
// Benutzer (verify_jwt).
// ============================================================================

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

// Regeln sauber verstehen ist wichtiger als Tempo; fällt auf Haiku zurück, falls nicht verfügbar
const MODELLE = ['claude-sonnet-5-5', 'claude-haiku-5-5', 'claude-haiku-4-5-20251001'];

const SYSTEM = `Du hilfst im Einsatzplaner der Gartenbaufirma Knechtgarten (Kanton Bern, Schweiz), Serientermine zu erfassen.
Der Benutzer beschreibt (oft gesprochen, Mundart möglich) eine oder mehrere Serien. Du füllst daraus die Felder aus.
Gib ausschliesslich JSON zurück: {"serien": [SERIE, ...], "hinweis": "..."}
SERIE = {
 "art": "abs" | "auf" | "mk",            // Absenz | Auftrag (Kunde/Titel) | Icon
 "abs": "<Absenz-Art aus der Liste>",     // nur bei art=abs
 "mk": "<Icon-Schlüssel aus der Liste>",  // nur bei art=mk
 "text": "...",                           // Titel (Auftrag) oder Hinweis (Icon), sonst ""
 "kunde": "...",                          // Kundenname, falls genannt, sonst ""
 "wer": ["<person-id>", ...],             // nur ids aus der Personenliste
 "vert": "alle" | "wechsel",              // wechsel = der Reihe nach abwechselnd (z. B. Ämtli aufteilen)
 "teil": "ganz" | "vm" | "nm",
 "regel": "woche" | "monat" | "taeglich", // taeglich = jeden Werktag
 "n": 1,                                  // bei woche: alle n Wochen
 "tage": [0],                             // bei woche: Wochentage 0=Mo … 5=Sa
 "nth": 1,                                // bei monat: 1–4 oder -1 = letzter
 "mwd": 1,                                // bei monat: Wochentag 0=Mo … 4=Fr
 "von": "YYYY-MM-DD", "bis": "YYYY-MM-DD",
 "ausFeier": true,                        // Feiertage auslassen (Standard true)
 "ausKW": "",                             // ausgelassene Kalenderwochen, z. B. "15-16, 52"
 "ausDat": ""                             // ausgelassene Daten/Zeiträume, z. B. "24.12.26-2.1.27, 13.4.27"
}
Regeln:
- Personen: «die Lehrlinge» = alle Personen der Gruppe mit «Lehrling» im Namen. Vornamen und Spitznamen (z. B. Fäbu = Fabian, Räphu = Raphael, Stefu = Stefan) passend zuordnen. Nur ids aus der Liste.
- Ohne Zeitraum: von = heute, bis = Ende des laufenden Schuljahres (31. Juli) bzw. in 6 Monaten.
- «Schule», «Berufsschule» = Absenz-Art «Schule». «Ämtli» = Icon «aemtli».
- «ausser in Monat X» = diese Monate als Zeitraum in ausDat. «ohne KW 15» = ausKW.
- Ferien ohne genaue Daten: setze die üblichen Daten im Kanton Bern als Vorschlag in ausDat (Weihnachtsferien ca. 24.12.–2.1.) und schreibe im "hinweis", dass die Daten geprüft werden sollen.
- Mehrere verschiedene Wünsche = mehrere Serien.
- "hinweis": ein bis zwei kurze Sätze auf Deutsch (Schweiz, ss statt ß), was du verstanden hast und was unklar ist. Leer, wenn alles klar ist.`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Nur POST.' }, 405);
  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Ungültige Anfrage.' }, 400); }
  const text = String(body?.text || '').trim().slice(0, 2000);
  if (!text) return json({ error: 'Text fehlt.' }, 400);
  const personen = (Array.isArray(body?.personen) ? body.personen : []).slice(0, 200)
    .map((p: any) => `${String(p.id).slice(0, 64)} | ${String(p.name || '').slice(0, 80)} | ${String(p.gruppe || '').slice(0, 80)}`).join('\n');
  const absenzen = (Array.isArray(body?.absenzen) ? body.absenzen : []).slice(0, 30).map((a: any) => String(a).slice(0, 40)).join(', ');
  const icons = (Array.isArray(body?.icons) ? body.icons : []).slice(0, 30).map((i: any) => `${String(i.key).slice(0, 20)} = ${String(i.name).slice(0, 40)}`).join(', ');
  const heute = String(body?.heute || new Date().toISOString().slice(0, 10)).slice(0, 10);

  const kontext = `Heute: ${heute}\nAbsenz-Arten: ${absenzen}\nIcons: ${icons}\nPersonen (id | Name | Gruppe):\n${personen}\n\nWunsch des Benutzers:\n${text}`;

  let letzterFehler = '';
  for (const model of MODELLE) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model, max_tokens: 2500, system: SYSTEM, messages: [{ role: 'user', content: kontext }] }),
    });
    const data = await res.json();
    if (!res.ok) { letzterFehler = data?.error?.message || `Anthropic-Fehler (${res.status})`; continue; }
    const out = (data.content || []).filter((c: any) => c.type === 'text').map((c: any) => c.text).join('');
    const m = out.match(/\{[\s\S]*\}/);
    try {
      const r = JSON.parse(m ? m[0] : out);
      return json({ serien: Array.isArray(r.serien) ? r.serien.slice(0, 10) : [], hinweis: String(r.hinweis || ''), modell: model });
    } catch {
      letzterFehler = 'Antwort der KI war nicht lesbar.';
    }
  }
  return json({ error: letzterFehler || 'KI nicht erreichbar.' }, 502);
});
