// ============================================================================
// wissen-verlinken – KI schlägt Verweise zwischen Wissen (Kapiteltext) und Einträgen vor.
// Aktionen (POST, nur eingeloggte Benutzer / verify_jwt):
//   { aktion: 'kapitel', text, eintraege: [{id, titel, untertitel, tags}], schon: [id] }
//     → { vorschlaege: [{ id, stelle, grund }] }   Stellen im Kapiteltext, die einen Eintrag meinen
//   { aktion: 'eintrag', eintrag: {id, titel, untertitel, tags}, kapitel: [{id, titel, text}] }
//     → { vorschlaege: [{ kapitel_id, stelle, grund }] }   wo ein (neuer) Eintrag im Wissen gemeint ist
// «stelle» ist wörtlich aus dem Text (wird hier geprüft), damit das Tool genau diese Wörter verlinken kann.
// Verlinkt wird erst, wenn jemand im Tool bestätigt.
// ============================================================================

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const MODELLE = ['claude-sonnet-5-5', 'claude-haiku-5-5'];

const REGELN = `Du arbeitest für die Gartenbaufirma Knechtgarten (Schweiz). Im internen Nachschlagewerk gibt es Einträge (Produkte, Geräte) und Wissens-Kapitel (Fliesstext).
Aufgabe: Finde Stellen im Text, die eindeutig einen bestimmten Eintrag meinen – auch wenn er anders genannt wird (Umschreibung, Kurzname, Wirkstoff, «die Umwälzpumpe» usw.).
Regeln:
- "stelle" muss WÖRTLICH und zusammenhängend im Text vorkommen (gleiche Schreibweise), 1 bis 6 Wörter, möglichst genau die Bezeichnung.
- Nur wenn du dir sicher bist, dass genau dieser Eintrag gemeint ist. Allgemeine Begriffe ohne klaren Bezug («Dünger», «Pumpe») nicht verlinken, ausser der Zusammenhang macht den Eintrag eindeutig.
- Pro Eintrag und Text höchstens eine Stelle (die erste passende).
- "grund": ein kurzer Satz auf Deutsch (ss statt ß), warum.
Gib ausschliesslich JSON zurück.`;

async function frageKI(key: string, system: string, inhalt: string) {
  let fehler = '';
  for (const model of MODELLE) {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model, max_tokens: 2000, system, messages: [{ role: 'user', content: inhalt }] }),
    });
    if (!res.ok) { fehler = `${model}: ${res.status} ${(await res.text()).slice(0, 200)}`; continue; }
    const d = await res.json();
    const text = (d.content || []).map((c: any) => c.text || '').join('');
    const m = text.match(/\{[\s\S]*\}/);
    try { return JSON.parse(m ? m[0] : text); } catch { fehler = `${model}: keine gültige Antwort`; }
  }
  throw new Error(fehler || 'KI nicht erreichbar');
}

const kurz = (s: unknown, n: number) => String(s ?? '').slice(0, n);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'Nur POST.' }, 405);
  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);
  let b: any; try { b = await req.json(); } catch { return json({ error: 'Ungültige Anfrage.' }, 400); }

  try {
    if (b?.aktion === 'kapitel') {
      const text = kurz(b.text, 20000), schon = new Set((b.schon || []).map(String));
      const liste = (Array.isArray(b.eintraege) ? b.eintraege : []).filter((e: any) => !schon.has(String(e.id))).slice(0, 400);
      if (!text.trim() || !liste.length) return json({ vorschlaege: [] });
      const einträge = liste.map((e: any) => `- id=${kurz(e.id, 64)} | ${kurz(e.titel, 120)}${e.untertitel ? ' | ' + kurz(e.untertitel, 120) : ''}${e.tags?.length ? ' | Suchwörter: ' + kurz((e.tags || []).join(', '), 120) : ''}`).join('\n');
      const r = await frageKI(key, REGELN + '\nFormat: {"vorschlaege":[{"id":"<Eintrag-id>","stelle":"<wörtlich aus dem Text>","grund":"..."}]}',
        `<eintraege>\n${einträge}\n</eintraege>\n\n<text>\n${text}\n</text>`);
      const ids = new Set(liste.map((e: any) => String(e.id)));
      const v = (r.vorschlaege || []).filter((x: any) => ids.has(String(x.id)) && x.stelle && text.includes(String(x.stelle)))
        .map((x: any) => ({ id: String(x.id), stelle: kurz(x.stelle, 120), grund: kurz(x.grund, 200) }));
      return json({ vorschlaege: v });
    }
    if (b?.aktion === 'eintrag') {
      const e = b.eintrag || {}, kap = (Array.isArray(b.kapitel) ? b.kapitel : []).slice(0, 80);
      if (!e.titel || !kap.length) return json({ vorschlaege: [] });
      const texte = kap.map((k: any) => `<kapitel id="${kurz(k.id, 64)}" titel="${kurz(k.titel, 120).replace(/"/g, "'")}">\n${kurz(k.text, 6000)}\n</kapitel>`).join('\n\n');
      const r = await frageKI(key, REGELN + '\nHier ist es umgekehrt: EIN Eintrag, mehrere Kapitel. Finde die Kapitel, in denen genau dieser Eintrag gemeint ist.\nFormat: {"vorschlaege":[{"kapitel_id":"<id>","stelle":"<wörtlich aus diesem Kapitel>","grund":"..."}]}',
        `<eintrag>\n${kurz(e.titel, 120)}${e.untertitel ? ' | ' + kurz(e.untertitel, 120) : ''}${e.tags?.length ? ' | Suchwörter: ' + kurz((e.tags || []).join(', '), 120) : ''}\n</eintrag>\n\n${texte}`);
      const byId = new Map(kap.map((k: any) => [String(k.id), String(k.text || '')]));
      const v = (r.vorschlaege || []).filter((x: any) => byId.has(String(x.kapitel_id)) && x.stelle && byId.get(String(x.kapitel_id))!.includes(String(x.stelle)))
        .map((x: any) => ({ kapitel_id: String(x.kapitel_id), stelle: kurz(x.stelle, 120), grund: kurz(x.grund, 200) }));
      return json({ vorschlaege: v });
    }
    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (err) {
    return json({ error: String((err as Error).message || err) }, 500);
  }
});
