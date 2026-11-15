// ============================================================================
// ki-offerte – Offerte im Gespräch erstellen (Offertentyp «KI» im Offerten-Blatt).
// Das Tool schickt den bisherigen Verlauf (nur Text), die neue Nachricht und das
// aktuelle Blatt. Claude sucht Artikel und alte Offerten über Werkzeuge und setzt
// das ganze Blatt mit «blatt_setzen». Preise kommen aus dem Artikelstamm oder aus
// alten Offerten; geschätzte Preise werden markiert. Nur eingeloggte Benutzer
// (verify_jwt). Modell: Claude Opus 5.5, bei Ablehnung automatischer Fallback.
// ============================================================================
import Anthropic from 'npm:@anthropic-ai/sdk';
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

const SYSTEM = `Du erstellst Offerten für Knechtgarten, ein Gartenbauunternehmen in Heimenschwand (Kanton Bern, Schweiz): Gartengestaltung, Bepflanzung, Bewässerung, Schwimmteiche, Pools, Mauern, Beläge.
Du sprichst mit dem Projektleiter (Du-Form, Schweizer Rechtschreibung mit ss, kurz und klar).

So arbeitest du:
- Das Blatt hat vier Kategorien: personal (Arbeitsleistung), maschine (Maschinenaufwand), logistik (Logistik, Transporte, Lieferwagen, Kran, Mulden), material (Materialaufwand, auch Pflanzen).
- Preise – Reihenfolge pro Zeile:
  1. Nennt der Projektleiter einen Preis, gilt dieser (quelle "vorgabe"), ohne Suche.
  2. Zeilen mit quelle "hand" im aktuellen Blatt hat der Projektleiter von Hand geändert: Preis, Menge und Einheit NIE ändern, quelle "hand" so zurückgeben (ausser er verlangt es ausdrücklich).
  3. artikel_suchen im Artikelstamm: passender Artikel → dessen Preis (vp_knecht) und Einheit, artikel_id, quelle "artikel", quelle_nr = Artikelnummer.
  4. Sonst easybill_suchen (Easybill-Angebote, v. a. Pflanzen und Spezialpositionen) und offerten_suchen (Offertentool): neusten passenden Preis nehmen, Preise aus den letzten 3 Jahren bevorzugen; ältere nur, wenn es nichts Neueres gibt. quelle "easybill" bzw. "offerte", quelle_id = die gelieferte quelle_id, quelle_nr = Angebots-/Offertnummer, quelle_datum, quelle_info = Kunde.
     Liegen die passenden Preise stark auseinander (über 30 %), nimm den neusten und nenne die Spanne in der Antwort (z. B. «CHF 280–420, 380 genommen»).
  5. Erst wenn alles nichts ergibt: vernünftig schätzen (quelle "geschaetzt").
  Höchstens 3 Suchen pro Position (z. B. «Carpinus Hochstamm», dann «Carpinus», dann «Hainbuche»), dann weiter. Erfinde keine Artikelnummern.
- Quellen in der Antwort: Wenn du eine Quelle erwähnst (alter oder geschätzter Preis, Spanne), schreibe sie als Link: [Angebot 17-11034](easybill:QUELLE_ID "Kunde · TT.MM.JJJJ") bzw. [Offerte 2026-010003](offerte:QUELLE_ID "Kunde · TT.MM.JJJJ"). Preise aus dem Artikelstamm nicht erwähnen. Ist ein übernommener Preis älter als 2 Jahre, sag das kurz.
- Personal: übliche Artikel sind «Polier / Vorarbeiter» und «Gartenarbeiter» (Std.). Arbeitstage × 9 Std. = Stunden, falls nichts anderes gesagt wird.
- Fahrzeit: Bei Personal-Zeilen (Polier, Gartenarbeiter, Servicetechniker) und beim Lieferwagen setzt du fahrt=true und gibst die Menge OHNE Fahrzeit an. Das Blatt rechnet die Fahrzeit zur Kundenadresse automatisch dazu. Beim Lieferwagen ohne eigene Einsatzstunden ist die Menge 0.
- Arbeitet Personal vor Ort, gehört IMMER eine Zeile «Lieferwagen» (Artikel suchen, Kategorie logistik, Std., fahrt=true) dazu – ausser der Projektleiter sagt ausdrücklich etwas anderes.
- Budget-Positionen (z. B. Kraneinsatz, Mulde, Kleinmaterial) mit Einheit «Budget» und Menge 1.
- Entsorgung: Anfallendes Material (Aushub, Schlamm, Pflanzenreste, Grüngut, Abbruch) wird bei uns IMMER abgeführt und entsorgt – rechne Abtransport und Entsorgung/Deponiegebühr immer ein, ohne nachzufragen. Nur wenn der Projektleiter ausdrücklich sagt, dass Material vor Ort bleibt, lässt du es weg.
- Bezeichnungen wie in einer Offerte an Kunden: verständlich, mit den wichtigen Angaben (Sorte, Grösse, Material), auf einer Zeile.
- Arbeitsbeschrieb: kurze Zeilen, die mit "- " beginnen, was gemacht wird (für den Kunden). Hinweise wie «bauseits» gehören auch hierhin.
- Wenn etwas Wichtiges fehlt (z. B. Menge, Grösse, Anzahl Tage), frag kurz nach, statt zu raten. Kleine Annahmen darfst du treffen und nennen.
- Sobald du etwas am Blatt änderst, rufe blatt_setzen mit dem VOLLSTÄNDIGEN neuen Blatt auf (alle Zeilen, auch unveränderte) und dem ganzen Arbeitsbeschrieb.
- Deine Antwort an den Projektleiter: 1-4 kurze Sätze, was du gemacht hast, welche Preise geschätzt oder alt sind und was noch offen ist. Keine Tabellen, keine Wiederholung aller Zeilen.`;

const TOOLS: Anthropic.Tool[] = [
  {
    name: 'artikel_suchen',
    description: 'Sucht im Artikelstamm von Knechtgarten nach Bezeichnung (Teilwörter möglich, mehrere Wörter = alle müssen vorkommen). Liefert id, Bezeichnung, Einheit, Verkaufspreis (vp_knecht, CHF exkl. MwSt), Kategorie, MwSt-Art.',
    input_schema: {
      type: 'object',
      properties: {
        suchbegriff: { type: 'string', description: 'z. B. "Polier", "Carpinus betulus", "Mulde"' },
        kategorie: { type: 'string', enum: ['personal', 'maschine', 'logistik', 'material'], description: 'optional einschränken' },
      },
      required: ['suchbegriff'],
      additionalProperties: false,
    },
  },
  {
    name: 'offerten_suchen',
    description: 'Sucht Zeilen in früheren Offerten nach einem Stichwort in der Bezeichnung (z. B. "Metallreif", "Kran"). Liefert Offertnummer, Kunde, Datum, Bezeichnung, Menge, Einheit, Preis – gut für Preise von Dingen ohne Artikel.',
    input_schema: {
      type: 'object',
      properties: { suchbegriff: { type: 'string' } },
      required: ['suchbegriff'],
      additionalProperties: false,
    },
  },
  {
    name: 'easybill_suchen',
    description: 'Sucht Positionen in früheren Easybill-Angeboten von Knechtgarten nach einem Stichwort in der Bezeichnung (z. B. "Carpinus", "Metallreif", "Kranwagen"). Liefert Angebotsnummer, Datum, Kunde, Bezeichnung, Menge, Einheit, Preis, Rabatt, MwSt. Die wichtigste Quelle für Pflanzen und Spezialpositionen ohne Artikel.',
    input_schema: {
      type: 'object',
      properties: { suchbegriff: { type: 'string', description: 'kurzes Stichwort, z. B. Gattung/Art einer Pflanze' } },
      required: ['suchbegriff'],
      additionalProperties: false,
    },
  },
  {
    name: 'blatt_setzen',
    description: 'Setzt das komplette Offerten-Blatt neu: alle Zeilen und den Arbeitsbeschrieb. Immer das vollständige Blatt schicken.',
    input_schema: {
      type: 'object',
      properties: {
        zeilen: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              kategorie: { type: 'string', enum: ['personal', 'maschine', 'logistik', 'material'] },
              bezeichnung: { type: 'string' },
              menge: { type: 'number' },
              einheit: { type: 'string' },
              preis: { type: 'number', description: 'CHF pro Einheit, exkl. MwSt' },
              artikel_id: { type: ['string', 'null'] },
              quelle: { type: 'string', enum: ['artikel', 'easybill', 'offerte', 'vorgabe', 'geschaetzt', 'hand'] },
              quelle_id: { type: ['string', 'null'], description: 'quelle_id aus easybill_suchen bzw. offerten_suchen (für den Link)' },
              quelle_nr: { type: ['string', 'null'], description: 'Artikelnummer, Offertnummer oder Easybill-Angebotsnummer' },
              quelle_datum: { type: ['string', 'null'], description: 'Datum der Quelle JJJJ-MM-TT (alte Offerte, Easybill-Angebot)' },
              quelle_info: { type: ['string', 'null'], description: 'kurz: Kunde der Quelle' },
              fahrt: { type: 'boolean', description: 'Personal/Lieferwagen: Menge ohne Fahrzeit, Fahrzeit rechnet das Blatt dazu' },
              optional: { type: 'boolean' },
            },
            required: ['kategorie', 'bezeichnung', 'menge', 'einheit', 'preis', 'quelle'],
            additionalProperties: false,
          },
        },
        arbeitsbeschrieb: { type: 'string', description: 'Zeilen mit "- " am Anfang' },
      },
      required: ['zeilen'],
      additionalProperties: false,
    },
  },
];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Nur POST.' }, 405);
  if (!Deno.env.get('ANTHROPIC_API_KEY')) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'Ungültige Anfrage.' }, 400); }
  const nachricht = String(body?.nachricht || '').trim().slice(0, 6000);
  if (!nachricht) return json({ error: 'Nachricht fehlt.' }, 400);
  // Diktat nach dem Stopp kurz korrigieren (schnelles Modell, nur Rechtschreibung/Fachbegriffe)
  if (body?.modus === 'korrigieren') {
    try {
      const r: any = await new Anthropic().messages.create({
        model: 'claude-haiku-5-5', max_tokens: 2000,
        system: 'Du korrigierst diktierten Text (Spracherkennung, Schweizerdeutsch gesprochen) für ein Gartenbau-Offertentool. Korrigiere nur Erkennungsfehler, Rechtschreibung (Schweiz, ss statt ß), Satzzeichen und Fachbegriffe aus Gartenbau, Pflanzen (botanische Namen), Poolbau. Inhalt, Zahlen und Reihenfolge nicht ändern, nichts ergänzen. Gib NUR den korrigierten Text zurück.',
        messages: [{ role: 'user', content: nachricht }],
      } as any);
      const text = (r.content || []).filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim();
      return json({ text: text || nachricht });
    } catch (e: any) { return json({ text: nachricht, fehler: String(e?.message || e) }); }
  }
  const verlauf: { rolle: string; text: string }[] = Array.isArray(body?.verlauf) ? body.verlauf.slice(-30) : [];
  const blatt = body?.blatt || {};
  const kunde = body?.kunde || {};

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  async function werkzeug(name: string, input: any): Promise<string> {
    if (name === 'artikel_suchen') {
      const woerter = String(input?.suchbegriff || '').trim().split(/\s+/).filter(Boolean).slice(0, 5);
      if (!woerter.length) return 'Kein Suchbegriff.';
      let q = sb.from('artikel').select('id, artikelnummer_knecht, bezeichnung, einheit, vp_knecht, kategorie, mwst_art').limit(20);
      for (const w of woerter) q = q.ilike('bezeichnung', `%${w.replace(/[%_]/g, '')}%`);
      if (input?.kategorie) q = q.eq('kategorie', input.kategorie);
      const { data, error } = await q;
      if (error) return 'Fehler: ' + error.message;
      if (!data?.length) return 'Keine Artikel gefunden.';
      return JSON.stringify(data);
    }
    if (name === 'offerten_suchen') {
      const { data, error } = await sb.rpc('ki_offerten_zeilen_suche', { begriff: String(input?.suchbegriff || '').slice(0, 80), anzahl: 20 });
      if (error) return 'Fehler: ' + error.message;
      if (!data?.length) return 'Keine Zeilen in alten Offerten gefunden.';
      return JSON.stringify(data);
    }
    if (name === 'easybill_suchen') {
      const { data, error } = await sb.rpc('ki_easybill_zeilen_suche', { begriff: String(input?.suchbegriff || '').slice(0, 80), anzahl: 20 });
      if (error) return 'Fehler: ' + error.message;
      if (!data?.length) return 'Keine Positionen in Easybill-Angeboten gefunden.';
      return JSON.stringify(data);
    }
    return 'Unbekanntes Werkzeug.';
  }

  // Easybill-Angebote einmal pro Tag im Hintergrund nachführen (ohne auf das Ergebnis zu warten)
  try {
    const { data: st } = await sb.from('easybill_sync_status').select('wert').eq('schluessel', 'angebote').maybeSingle();
    const zuletzt = st?.wert?.letzter_lauf ? new Date(st.wert.letzter_lauf).getTime() : 0;
    if (Date.now() - zuletzt > 24 * 3600 * 1000) {
      const lauf = fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/easybill-angebote-sync`, {
        method: 'POST', headers: { Authorization: `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`, 'Content-Type': 'application/json' }, body: '{}',
      }).catch(() => null);
      (globalThis as any).EdgeRuntime?.waitUntil?.(lauf);
    }
  } catch { /* Nachführen ist nicht kritisch */ }

  // Verlauf als reiner Text (abwechselnd user/assistant), dann die neue Nachricht mit dem aktuellen Blatt als Kontext
  const messages: any[] = [];
  for (const m of verlauf) {
    const rolle = m?.rolle === 'assistant' ? 'assistant' : 'user';
    const text = String(m?.text || '').trim();
    if (!text) continue;
    if (messages.length && messages[messages.length - 1].role === rolle) messages[messages.length - 1].content += '\n\n' + text;
    else messages.push({ role: rolle, content: text });
  }
  if (messages.length && messages[0].role !== 'user') messages.shift();
  const kontext = `<heute>${new Date().toISOString().slice(0, 10)}</heute>
<kunde>${JSON.stringify(kunde)}</kunde>\n<aktuelles_blatt>${JSON.stringify(blatt).slice(0, 30000)}</aktuelles_blatt>`;
  const neu = `${kontext}\n\n${nachricht}`;
  if (messages.length && messages[messages.length - 1].role === 'user') messages[messages.length - 1].content += '\n\n' + neu;
  else messages.push({ role: 'user', content: neu });

  const client = new Anthropic();
  let gesetzt: any = null, antwort = '', modell = '', suchen = 0;
  try {
    for (let runde = 0; runde < 10; runde++) {
      const response: any = await client.beta.messages.create({
        model: 'claude-opus-5-5',
        max_tokens: 16000,
        system: SYSTEM,
        tools: TOOLS,
        messages,
        thinking: { type: 'adaptive' },
        output_config: { effort: 'medium' },
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
      } as any);
      modell = response.model;
      if (response.stop_reason === 'refusal') {
        return json({ antwort: 'Dazu kann ich leider nichts erstellen. Formuliere die Anfrage bitte anders.', zeilen: null, modell });
      }
      const texte = response.content.filter((b: any) => b.type === 'text').map((b: any) => b.text).join('\n').trim();
      if (texte) antwort = texte;
      if (response.stop_reason === 'pause_turn') { messages.push({ role: 'assistant', content: response.content }); continue; }
      const aufrufe = response.content.filter((b: any) => b.type === 'tool_use');
      if (response.stop_reason !== 'tool_use' || !aufrufe.length) break;
      messages.push({ role: 'assistant', content: response.content });
      const ergebnisse: any[] = [];
      for (const t of aufrufe) {
        let inhalt = '';
        if (t.name === 'blatt_setzen') {
          const z = t.input?.zeilen;
          if (!Array.isArray(z)) inhalt = 'Fehler: zeilen fehlt.';
          else { gesetzt = { zeilen: z.slice(0, 200), arbeitsbeschrieb: typeof t.input?.arbeitsbeschrieb === 'string' ? t.input.arbeitsbeschrieb : null }; inhalt = `Blatt gesetzt (${z.length} Zeilen).`; }
        } else {
          inhalt = ++suchen > 25 ? 'Suchlimit erreicht – nimm, was du gefunden hast, oder schätze (quelle "geschaetzt").' : await werkzeug(t.name, t.input);
        }
        ergebnisse.push({ type: 'tool_result', tool_use_id: t.id, content: inhalt });
      }
      messages.push({ role: 'user', content: ergebnisse });
    }
  } catch (e: any) {
    const status = e?.status || 500;
    return json({ error: status === 429 ? 'Die KI ist gerade ausgelastet, bitte gleich nochmals versuchen.' : ('KI-Fehler: ' + (e?.message || e)) }, status >= 400 && status < 600 ? status : 500);
  }
  return json({ antwort: antwort || (gesetzt ? 'Blatt aktualisiert.' : ''), zeilen: gesetzt?.zeilen ?? null, arbeitsbeschrieb: gesetzt?.arbeitsbeschrieb ?? null, modell });
});
