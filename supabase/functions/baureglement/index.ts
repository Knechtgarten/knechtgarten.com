// ============================================================================
// Baureglement der Gemeinde (Kanton Bern) für «Pläne & Bewill.»
// Der ÖREB-Auszug eines Grundstücks verweist auf das Gemeindebaureglement (PDF, oft eingescannt).
// Einmal pro Gemeinde liest Claude das PDF direkt über den Link und speichert eine Zonentabelle und die
// für einen Gartenbauer wichtigen Themen mit Artikel (Tabelle baureglement). Läuft im Hintergrund.
// Aktionen:
//   { aktion: 'holen', bewilligung_id, neu? }  → Gemeinde, Zone der Parzelle, Auszug (oder status 'laeuft')
//   { aktion: 'frage', bewilligung_id, frage, original? } → Antwort mit Artikel (original: im PDF nachlesen)
//   { aktion: 'eigentuemer', pdf (base64) } → Eigentümer aus einer eingescannten Grundstückliste (ohne Textebene)
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const OEREB = 'https://www.oereb2.apps.be.ch';
const MODELLE = ['claude-sonnet-5-5', 'claude-haiku-5-5', 'claude-haiku-4-5-20251001'];
const de = (t: any) => Array.isArray(t) ? (t.find((x: any) => x.Language === 'de')?.Text ?? t[0]?.Text ?? '') : (t ?? '');

async function claude(content: any[], system: string, maxTokens: number) {
  const key = Deno.env.get('ANTHROPIC_API_KEY'); if (!key) throw new Error('ANTHROPIC_API_KEY fehlt.');
  let letzter = '';
  for (const model of MODELLE) {
    const r = await fetch('https://api.anthropic.com/v1/messages', { method: 'POST',
      headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
      body: JSON.stringify({ model, max_tokens: maxTokens, system, messages: [{ role: 'user', content }] }) });
    const d = await r.json().catch(() => ({}));
    if (r.ok) return { text: (d.content || []).filter((c: any) => c.type === 'text').map((c: any) => c.text).join(''), model };
    letzter = d?.error?.message || String(r.status);
    if (r.status !== 404 && r.status !== 400 && r.status !== 529) break;   // anderes Modell nur bei «gibt es nicht» / Überlast
  }
  throw new Error('KI: ' + letzter);
}
const jsonAus = (t: string) => { const m = t.match(/\{[\s\S]*\}/); return m ? JSON.parse(m[0]) : null; };

const SYS_AUSZUG = `Du liest ein Gemeindebaureglement aus dem Kanton Bern (Schweiz) für eine Gartenbaufirma (Pools, Gartenmauern, Terrainanpassungen, Bepflanzung).
Antworte NUR mit JSON in dieser Form:
{"stand":"kurz, z. B. Stand Juli 2024","zonen":[{"name":"Wohnzone 2","kuerzel":"W2","grenzabstand_klein":"4.00 m","grenzabstand_gross":"8.00 m","fassadenhoehe":"7.00 m","gesamthoehe":"","geschosse":"2","gebaeudelaenge":"","gruenflaechenziffer":"0.40","ueberbauungsziffer":"","es":"II","bauweise":"offen","artikel":"Art. 21"}],
"themen":[{"thema":"Grünflächenziffer","text":"kurz und konkret","artikel":"Art. 30"}]}
Themen (wenn im Reglement geregelt): Grünflächenziffer, Grenzabstände allgemein und für Nebenbauten/An- und Kleinbauten, Unterirdische Bauten und Schwimmbäder, Abgrabungen und Aufschüttungen/Terrainveränderungen, Stützmauern und Einfriedungen/Sichtschutz, Bepflanzung/Hecken/Bäume (Abstände), Parkplätze/Vorplätze, Wärmepumpen/Anlagen, Gestaltung/Umgebung.
Werte genau wie im Reglement (mit Einheit), unbekannt = "". Keine Erfindungen. Deutsch, Schweizer Schreibweise (ss).`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: { user } } = await nutzer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: ich } = await admin.from('benutzer').select('rolle,aktiv').eq('id', user.id).maybeSingle();
    if (!['admin', 'buero_team'].includes(ich?.rolle) || ich?.aktiv === false) return json({ error: 'Nur für das Büro.' }, 403);
    const body = await req.json();

    if (body.aktion === 'eigentuemer') {
      const pdf = String(body.pdf || ''); if (!pdf) return json({ error: 'Kein PDF erhalten.' }, 400);
      const sys = `Du liest eine Grundstückliste (Eigentümerliste) eines Berner Geometers. Antworte NUR mit JSON:
{"eigentuemer":[{"name":"Sandro und Tamara Bertolino","adresse":"Untere Gasse 55f, 3645 Zwieselberg","parzellen":["369"]}]}
Regeln: pro Eigentümer bzw. Eigentümergemeinschaft ein Eintrag; gleiche Eigentümer mit mehreren Grundstücken zusammenfassen (alle Nummern in parzellen).
Personen als «Vorname Nachname», mehrere Personen mit «und» (gleicher Nachname: «Sandro und Tamara Bertolino»). Firmen und Gemeinden unverändert.
Adresse ohne «Schweiz». Anmerkungsgrundstücke und «jeweilige Eigentümer» weglassen. Nichts erfinden.`;
      const r = await claude([{ type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: pdf } }, { type: 'text', text: 'Eigentümer als JSON.' }], sys, 4000);
      return json({ eigentuemer: jsonAus(r.text)?.eigentuemer || [] });
    }
    const { data: b } = await admin.from('bewilligung').select('id,egrid,reglement,geodaten').eq('id', body.bewilligung_id).maybeSingle();
    if (!b?.egrid) return json({ error: 'Gesuch ohne EGRID (zuerst Geodaten holen).' }, 400);

    // ÖREB: Gemeinde, Zone der Grundnutzung und Links zum Gemeindebaureglement
    const x = (await (await fetch(`${OEREB}/extract/json?EGRID=${b.egrid}`)).json())?.GetExtractByIdResponse?.extract;
    const re = x?.RealEstate || {}, bfs = Number(re.MunicipalityCode), gemeinde = re.MunicipalityName || '';
    const grund = (re.RestrictionOnLandownership || []).find((r: any) => /Grundnutzung/.test(de(r.Theme?.Text)));
    const zone = grund ? de(grund.LegendText) : '';
    const urls: { titel: string, url: string }[] = [];
    for (const r of re.RestrictionOnLandownership || []) for (const p of r.LegalProvisions || []) {
      const u = de(p.TextAtWeb), t = de(p.Title);
      if (u && /\.pdf$/i.test(u) && /reglement/i.test(t) && /oerebfiles/.test(u) && !/Gew(ä|ae)sserschutz/i.test(u) && !urls.some(z => z.url === u)) urls.push({ titel: t, url: u });
    }
    if (!bfs) return json({ error: 'Gemeinde im ÖREB-Auszug nicht gefunden.' }, 404);

    let { data: br } = await admin.from('baureglement').select('*').eq('bfs_nr', bfs).maybeSingle();

    if (body.aktion === 'holen') {
      const alt = br && br.status === 'laeuft' && Date.now() - new Date(br.aktualisiert_am).getTime() > 10 * 60e3;   // hängengeblieben
      if (!br || body.neu || alt || (br.status === 'fehler' && body.neu !== false)) {
        if (!urls.length) return json({ gemeinde, bfs, zone, status: 'fehler', fehler: 'Im ÖREB-Auszug ist kein Gemeindebaureglement verlinkt.' });
        await admin.from('baureglement').upsert({ bfs_nr: bfs, gemeinde, urls, status: 'laeuft', fehler: null, aktualisiert_am: new Date().toISOString() });
        // im Hintergrund lesen (1–2 Minuten), das Gesuch fragt nach
        const arbeit = (async () => {
          try {
            const inhalt: any[] = urls.slice(0, 2).map(u => ({ type: 'document', source: { type: 'url', url: u.url }, title: u.titel }));
            inhalt.push({ type: 'text', text: `Gemeinde ${gemeinde}. Erstelle den Auszug als JSON.` });
            const r = await claude(inhalt, SYS_AUSZUG, 16000);
            const a = jsonAus(r.text); if (!a?.zonen) throw new Error('Antwort der KI war kein gültiger Auszug.');
            await admin.from('baureglement').update({ status: 'fertig', auszug: a, modell: r.model, fehler: null, aktualisiert_am: new Date().toISOString() }).eq('bfs_nr', bfs);
          } catch (e) {
            await admin.from('baureglement').update({ status: 'fehler', fehler: String((e as any)?.message || e), aktualisiert_am: new Date().toISOString() }).eq('bfs_nr', bfs);
          }
        })();
        // @ts-ignore EdgeRuntime gibt es in Supabase Edge Functions
        if (typeof EdgeRuntime !== 'undefined') EdgeRuntime.waitUntil(arbeit); else await arbeit;
        return json({ gemeinde, bfs, zone, urls, status: 'laeuft' });
      }
      // Zone der Parzelle in der Zonentabelle finden (einmal pro Gesuch, KI wählt bei unklaren Namen)
      let zi = b.reglement?.bfs_nr === bfs && b.reglement?.zone_oereb === zone ? b.reglement.zone_index : undefined;
      if (br.status === 'fertig' && zi === undefined && zone) {
        const zonen = (br.auszug?.zonen || []).map((z: any, i: number) => `${i}: ${z.name}${z.kuerzel ? ' (' + z.kuerzel + ')' : ''}`).join('\n');
        try { const r = await claude([{ type: 'text', text: `Zone laut ÖREB-Kataster: «${zone}».\nZonen im Baureglement:\n${zonen}\nWelche Nummer passt? Antworte nur mit JSON {"index": Zahl oder null}.` }], 'Du ordnest Zonen zu. Nur JSON.', 50);
          zi = jsonAus(r.text)?.index ?? null; } catch (_) { zi = null; }
        await admin.from('bewilligung').update({ reglement: { bfs_nr: bfs, zone_oereb: zone, zone_index: zi } }).eq('id', b.id);
      }
      return json({ gemeinde, bfs, zone, urls: br.urls, status: br.status, fehler: br.fehler, auszug: br.auszug, zone_index: zi ?? null, aktualisiert_am: br.aktualisiert_am });
    }

    if (body.aktion === 'frage') {
      const frage = String(body.frage || '').trim(); if (!frage) return json({ error: 'Frage fehlt.' }, 400);
      const inhalt: any[] = [];
      if (body.original || !br?.auszug) inhalt.push(...(br?.urls || urls).slice(0, 2).map((u: any) => ({ type: 'document', source: { type: 'url', url: u.url }, title: u.titel })));
      else inhalt.push({ type: 'text', text: 'Auszug aus dem Baureglement (JSON):\n' + JSON.stringify(br.auszug) });
      inhalt.push({ type: 'text', text: `Gemeinde ${gemeinde}, Zone der Parzelle laut ÖREB: «${zone}».\nFrage: ${frage}` });
      const r = await claude(inhalt, `Du beantwortest Fragen zum Baureglement der Gemeinde für eine Gartenbaufirma. Kurz und konkret, mit Artikel (z. B. «Art. 21 Abs. 2»). Sprich in der Du-Form. Nur was im Reglement steht; steht es nicht drin, sag das klar${body.original ? '' : ' und empfiehl «im Original nachlesen»'}. Deutsch, Schweizer Schreibweise (ss).`, 1200);
      return json({ antwort: r.text.trim(), original: !!body.original, modell: r.model });
    }
    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (e) {
    return json({ error: String((e as any)?.message || e) }, 500);
  }
});
