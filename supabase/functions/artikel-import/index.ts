// ============================================================================
// Artikel-Import (Artikelstamm › «+ Artikel» › Aus Liste oder Bild, und «Preisabgleich»)
// Liest Artikel mit Preisen aus einem Bild, einem PDF oder Text (CSV/Excel wird im Browser zu Text)
// und gibt sie als Liste zurück. Grosse Listen teilt der Browser in Stücke auf.
// Aufruf: { bild?: dataURL, pdf?: base64, text?: string, hinweis?: string, lieferant?: string }
// Antwort: { artikel: [{ nr, bezeichnung, einheit, preis }] }
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const MODELLE = ['claude-sonnet-5-5', 'claude-haiku-5-5', 'claude-haiku-4-5-20251001'];

const SYS = `Du liest Artikel mit Preisen aus einer Preisliste, einem Shop-Screenshot, einer Offerte oder einer E-Mail eines Lieferanten (Gartenbau, Pool, Bau).
Antworte NUR mit JSON: {"artikel":[["Artikelnummer","Bezeichnung","Einheit",Preis]]}
- Artikelnummer genau so wie beim Lieferanten (leer "" wenn keine).
- Bezeichnung vollständig, mit Grösse/Variante, ohne Preis.
- Einheit kurz (Stk., m, m², m³, kg, l, Pkg., Sack, Std.); unbekannt: "Stk.".
- Preis als Zahl für eine Einheit, so wie er dasteht (nicht umrechnen, keine MwSt rechnen). Mehrere Preise (z. B. Staffel): den für 1 Einheit. Kein Preis: null.
- Jede Variante ist ein eigener Artikel. Nichts erfinden, keine Überschriften oder Summen.`;

async function claude(content: any[]) {
  const key = Deno.env.get('ANTHROPIC_API_KEY'); if (!key) throw new Error('ANTHROPIC_API_KEY fehlt.');
  let letzter = '';
  for (const model of MODELLE) {
    const r = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model, max_tokens: 16000, system: SYS, messages: [{ role: 'user', content }] }) });
    const d = await r.json().catch(() => ({}));
    if (r.ok) return (d.content || []).filter((c: any) => c.type === 'text').map((c: any) => c.text).join('');
    letzter = d?.error?.message || String(r.status);
    if (r.status !== 404 && r.status !== 400 && r.status !== 529) break;
  }
  throw new Error('KI: ' + letzter);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: { user } } = await nutzer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const body = await req.json();
    const inhalt: any[] = [];
    if (body.bild) { const m = String(body.bild).match(/^data:(image\/[a-z+]+);base64,(.*)$/); if (!m) return json({ error: 'Bild nicht lesbar.' }, 400);
      inhalt.push({ type: 'image', source: { type: 'base64', media_type: m[1], data: m[2] } }); }
    if (body.pdf) inhalt.push({ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: String(body.pdf) } });
    if (body.text) inhalt.push({ type: 'text', text: 'Inhalt:\n' + String(body.text).slice(0, 120000) });
    if (!inhalt.length) return json({ error: 'Nichts zum Lesen erhalten.' }, 400);
    inhalt.push({ type: 'text', text: `${body.lieferant ? 'Lieferant: ' + body.lieferant + '. ' : ''}${body.hinweis ? 'Hinweis: ' + body.hinweis + '. ' : ''}Gib alle Artikel als JSON zurück.` });
    const t = await claude(inhalt);
    const m = t.match(/\{[\s\S]*\}/); const d = m ? JSON.parse(m[0]) : null;
    const artikel = (d?.artikel || []).map((a: any) => Array.isArray(a)
      ? { nr: String(a[0] ?? '').trim(), bezeichnung: String(a[1] ?? '').trim(), einheit: String(a[2] ?? 'Stk.').trim() || 'Stk.', preis: typeof a[3] === 'number' ? a[3] : (parseFloat(String(a[3] ?? '').replace(/[^\d.,-]/g, '').replace(',', '.')) || null) }
      : a).filter((a: any) => a.bezeichnung);
    return json({ artikel });
  } catch (e) {
    return json({ error: String((e as any)?.message || e) }, 500);
  }
});
