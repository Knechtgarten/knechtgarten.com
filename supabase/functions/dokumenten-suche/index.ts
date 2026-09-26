// ============================================================================
// Dokumenten-Suche - Phase 3: KI-Ebene.
//
// Anders als Phase 2 (1:1-Weiterleitung des Suchbegriffs) leitet Claude hier
// aus der Nutzerfrage selbst passende Drive-/Gmail-Suchanfragen ab (kann
// mehrere, mit Synonymen/verwandten Begriffen), sichtet die Treffer und
// liefert eine bewertete, begruendete Liste zurueck ("Hohe/Moegliche
// Uebereinstimmung", warum gefunden, vermutete Dokumentart) - genau der
// Unterschied zur reinen Stichwortsuche, um den es beim ganzen Projekt geht.
//
// Ablauf: Claude bekommt zwei Werkzeuge (drive_suchen, gmail_suchen) und ruft
// sie selbst auf (Tool-Use-Schleife, max. 4 Runden als Sicherheitsbremse),
// bis es genug gesehen hat, dann liefert es ueber ein drittes Werkzeug
// (ergebnisse_liefern) die fertige Bewertung. Die eigentlichen Metadaten
// (Titel/Link/Datum/Dateityp) uebernehmen wir NICHT aus Claudes Antwort,
// sondern holen sie anhand der von Claude referenzierten ID aus den echten,
// zuvor gesammelten Google-Rohtreffern - damit kann die KI keinen Link
// verfaelschen oder erfinden, nur auswaehlen/bewerten/begruenden.
//
// PEAX ist weiterhin NICHT Teil dieser Function (kein API-Zugang) - siehe
// Projekt-Notiz. Die Erweiterung oeffnet PEAX' eigene Suche separat.
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

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

interface RohTreffer {
  quelle: 'drive' | 'gmail';
  id: string;
  titel: string;
  snippet: string;
  datum: string | null;
  link: string;
  dateityp?: string;
}

// Google-Drive-Suchsyntax verlangt Escaping von Apostrophen im Suchbegriff.
function escapeDriveQuery(text: string): string {
  return text.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

async function sucheDrive(begriff: string, token: string, zeitraumVon?: string): Promise<RohTreffer[]> {
  const bedingungen = [`fullText contains '${escapeDriveQuery(begriff)}'`, 'trashed = false'];
  if (zeitraumVon) bedingungen.push(`modifiedTime >= '${zeitraumVon}'`);
  const params = new URLSearchParams({
    q: bedingungen.join(' and '),
    fields: 'files(id,name,mimeType,modifiedTime,webViewLink)',
    pageSize: '10',
  });
  const res = await fetch(`https://www.googleapis.com/drive/v3/files?${params}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) throw new Error(`Drive-Suche fehlgeschlagen (${res.status}): ${await res.text()}`);
  const data = await res.json();
  return (data.files || []).map((f: any) => ({
    quelle: 'drive' as const,
    id: f.id,
    titel: f.name,
    snippet: '',
    datum: f.modifiedTime ?? null,
    link: f.webViewLink,
    dateityp: f.mimeType,
  }));
}

async function sucheGmail(begriff: string, token: string, zeitraumVon?: string, papierkorbSpam = false): Promise<RohTreffer[]> {
  let gmailQuery = begriff;
  if (zeitraumVon) gmailQuery += ` after:${zeitraumVon.slice(0, 10).replace(/-/g, '/')}`;
  if (papierkorbSpam) gmailQuery += ' in:anywhere';
  const listParams = new URLSearchParams({ q: gmailQuery, maxResults: '10' });
  const listRes = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages?${listParams}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!listRes.ok) throw new Error(`Gmail-Suche fehlgeschlagen (${listRes.status}): ${await listRes.text()}`);
  const liste = await listRes.json();
  const ids: string[] = (liste.messages || []).map((m: any) => m.id);

  const details = await Promise.all(ids.map(async (id) => {
    const params = new URLSearchParams({ format: 'metadata', metadataHeaders: 'Subject' });
    const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${id}?${params}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return null;
    const msg = await res.json();
    const betreff = msg.payload?.headers?.find((h: any) => h.name === 'Subject')?.value || '(kein Betreff)';
    return {
      quelle: 'gmail' as const,
      id: msg.id,
      titel: betreff,
      snippet: msg.snippet || '',
      datum: msg.internalDate ? new Date(Number(msg.internalDate)).toISOString() : null,
      link: `https://mail.google.com/mail/u/0/#all/${msg.id}`,
    };
  }));
  return details.filter((d): d is RohTreffer => d !== null);
}

// ---------------------------------------------------------------------------
// Claude-Orchestrierung
// ---------------------------------------------------------------------------
const TOOLS = [
  {
    name: 'drive_suchen',
    description: 'Durchsucht Google Drive (Dateiname + Inhalt) nach einem Begriff. Mehrfach mit verschiedenen Formulierungen/Synonymen aufrufbar.',
    input_schema: {
      type: 'object',
      properties: { begriff: { type: 'string', description: 'Suchbegriff, moeglichst spezifisch (z.B. Firmenname, Artikelbezeichnung, Aktenzeichen).' } },
      required: ['begriff'],
    },
  },
  {
    name: 'gmail_suchen',
    description: 'Durchsucht Gmail (Betreff, Mailtext, Absender) nach einem Begriff. Mehrfach mit verschiedenen Formulierungen/Synonymen aufrufbar.',
    input_schema: {
      type: 'object',
      properties: { begriff: { type: 'string', description: 'Suchbegriff, moeglichst spezifisch.' } },
      required: ['begriff'],
    },
  },
  {
    name: 'ergebnisse_liefern',
    description: 'Schliesst die Suche ab und liefert die bewertete Ergebnisliste. Erst aufrufen, wenn genug gesucht wurde (meist 1-4 Suchaufrufe reichen).',
    input_schema: {
      type: 'object',
      properties: {
        bewertungen: {
          type: 'array',
          description: 'Nur tatsaechlich relevante Treffer aus den vorherigen Suchergebnissen, beste Uebereinstimmung zuerst.',
          items: {
            type: 'object',
            properties: {
              id: { type: 'string', description: 'Die id des Treffers, exakt wie im Suchergebnis erhalten.' },
              quelle: { type: 'string', enum: ['drive', 'gmail'] },
              uebereinstimmung: { type: 'string', enum: ['hoch', 'moeglich'] },
              begruendung: { type: 'string', description: 'Kurz, 1 Satz: warum dieser Treffer passt (welcher Begriff/Kontext gefunden wurde).' },
              dokumentart: { type: 'string', description: 'Beste Vermutung aus der mitgegebenen Liste erlaubter Dokumentarten, oder leer lassen falls nicht erkennbar.' },
            },
            required: ['id', 'quelle', 'uebereinstimmung', 'begruendung'],
          },
        },
      },
      required: ['bewertungen'],
    },
  },
];

function baueSystemPrompt(dokumentarten: string[], suchgenauigkeit: string): string {
  const genauigkeitsHinweis = {
    genau: 'Suchgenauigkeit "Genau": nutze ausschliesslich den exakten, vom Nutzer eingegebenen Begriff woertlich, keine Synonyme oder verwandte Begriffe erfinden.',
    teilwort: 'Suchgenauigkeit "Teilwort": der Begriff darf auch als Teil eines laengeren Worts vorkommen (z.B. "Technik" in "Gartentechnik") - trotzdem nah am Wortlaut bleiben, keine Synonyme.',
    sinngemaess: 'Suchgenauigkeit "Sinngemaess": denk aktiv mit - leite aus der Frage mehrere sinnvolle Suchbegriffe ab (Synonyme, Firmennamen, Artikelbezeichnungen, naheliegende Umformulierungen), nicht nur den Wortlaut der Frage 1:1 verwenden.',
  }[suchgenauigkeit] || '';

  return `Du hilfst einer Gartenbau-Firma (Knechtgarten), Dokumente in Google Drive und Gmail zu finden.
Die Nutzerin/der Nutzer beschreibt, was sie/er sucht - oft ungenau oder nur ungefaehr erinnert (z.B. "das Angebot fuer den Spezialkleber, weiss nicht mehr von welchem Lieferanten").

${genauigkeitsHinweis}

Vorgehen:
1. Rufe drive_suchen und/oder gmail_suchen mit gut gewaehlten Suchbegriffen auf (nicht zwingend beide Quellen, nur wo sinnvoll).
2. Bei Bedarf mit anderen Begriffen nochmal suchen, wenn die ersten Treffer nicht ueberzeugen. Insgesamt reichen normalerweise 1-4 Suchaufrufe.
3. Wenn du genug gesehen hast, rufe ergebnisse_liefern auf. Nimm dort NUR Treffer auf, die wirklich zur Anfrage passen (nicht die komplette Rohliste durchreichen). Bewerte jeden Treffer ehrlich: "hoch" nur wenn du dir wirklich sicher bist, sonst "moeglich".
4. Erlaubte Dokumentarten fuer das Feld "dokumentart" (nur wenn eindeutig erkennbar, sonst weglassen): ${dokumentarten.join(', ') || '(keine Liste hinterlegt)'}.

Antworte ausschliesslich durch Werkzeug-Aufrufe, keinen Fliesstext.`;
}

async function rufeClaudeMitTools(system: string, messages: any[]) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-5',
      max_tokens: 2000,
      system,
      tools: TOOLS,
      messages,
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.message || `Anthropic-Fehler (${res.status})`);
  return data;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Ungueltiger Request-Body (JSON erwartet).' }, 400);
  }

  const { query, mitarbeiterEmail, googleAccessToken, quellen, zeitraumVon, papierkorbSpam, suchgenauigkeit, maxRunden, kundeFirma } = body ?? {};
  if (!query || typeof query !== 'string') return json({ error: 'query fehlt.' }, 400);
  if (!mitarbeiterEmail || typeof mitarbeiterEmail !== 'string') return json({ error: 'mitarbeiterEmail fehlt.' }, 400);
  if (!googleAccessToken || typeof googleAccessToken !== 'string') return json({ error: 'googleAccessToken fehlt.' }, 400);
  if (!Deno.env.get('ANTHROPIC_API_KEY')) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);

  const gewuenschteQuellen: string[] = Array.isArray(quellen) && quellen.length ? quellen : ['drive', 'gmail'];
  const genauigkeit = ['genau', 'teilwort', 'sinngemaess'].includes(suchgenauigkeit) ? suchgenauigkeit : 'sinngemaess';

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  let dokumentarten: string[] = [];
  try {
    const { data } = await sb.from('dokumentensuche_dokumentart').select('name').eq('aktiv', true).order('sortierung');
    dokumentarten = (data || []).map((d: any) => d.name);
  } catch (e) {
    console.error('Dokumentarten-Abfrage fehlgeschlagen:', e);
  }

  const gesehen = new Map<string, RohTreffer>();
  const suchschritte: { quelle: string; begriff: string }[] = [];
  const fehler: string[] = [];

  async function fuehreToolAus(name: string, input: any): Promise<string> {
    try {
      let treffer: RohTreffer[] = [];
      if (name === 'drive_suchen' && gewuenschteQuellen.includes('drive')) {
        treffer = await sucheDrive(input.begriff, googleAccessToken, zeitraumVon);
        suchschritte.push({ quelle: 'drive', begriff: input.begriff });
      } else if (name === 'gmail_suchen' && gewuenschteQuellen.includes('gmail')) {
        treffer = await sucheGmail(input.begriff, googleAccessToken, zeitraumVon, !!papierkorbSpam);
        suchschritte.push({ quelle: 'gmail', begriff: input.begriff });
      } else {
        return 'Diese Quelle ist fuer diese Suche nicht ausgewaehlt.';
      }
      for (const t of treffer) gesehen.set(`${t.quelle}:${t.id}`, t);
      if (!treffer.length) return 'Keine Treffer.';
      return treffer.map((t) => `id=${t.id} | ${t.titel}${t.snippet ? ' | ' + t.snippet : ''} | ${t.datum ?? ''}`).join('\n');
    } catch (e) {
      const msg = String(e instanceof Error ? e.message : e);
      fehler.push(msg);
      return `Fehler: ${msg}`;
    }
  }

  const system = baueSystemPrompt(dokumentarten, genauigkeit);
  const kundeHinweis = typeof kundeFirma === 'string' && kundeFirma.trim()
    ? `\nZusatzhinweis: Der gesuchte Kunde/die Firma ist "${kundeFirma.trim()}" - beziehe das stark in Suche und Bewertung ein (z.B. als zusaetzlichen Suchbegriff, und werte Treffer ohne erkennbaren Bezug dazu als hoechstens "moeglich").`
    : '';
  const messages: any[] = [{ role: 'user', content: `Suchanfrage: ${query}${kundeHinweis}` }];

  let bewertungen: any[] = [];
  // Nutzer-waehlbare Sicherheitsbremse (Schnell/Normal/Ausfuehrlich in der
  // Erweiterung) - hart begrenzt, damit eine falsche/manipulierte Eingabe
  // keine beliebig teure Endlosschleife an Claude-Aufrufen ausloesen kann.
  const MAX_RUNDEN = Math.min(10, Math.max(1, Number(maxRunden) || 4));
  for (let runde = 0; runde < MAX_RUNDEN; runde++) {
    const antwort = await rufeClaudeMitTools(system, messages);
    const toolUseBloecke = (antwort.content || []).filter((c: any) => c.type === 'tool_use');
    const abschluss = toolUseBloecke.find((c: any) => c.name === 'ergebnisse_liefern');

    if (abschluss) {
      bewertungen = abschluss.input?.bewertungen || [];
      break;
    }
    if (!toolUseBloecke.length) break; // Claude hat aus irgendeinem Grund keinen Tool-Call gemacht - abbrechen statt haengenzubleiben.

    messages.push({ role: 'assistant', content: antwort.content });
    const toolResults = await Promise.all(toolUseBloecke.map(async (block: any) => ({
      type: 'tool_result',
      tool_use_id: block.id,
      content: await fuehreToolAus(block.name, block.input),
    })));
    messages.push({ role: 'user', content: toolResults });
  }

  // Claudes Bewertung + unsere eigenen, vertrauenswuerdigen Rohdaten zusammenfuehren.
  const ergebnisse = bewertungen
    .map((b: any) => {
      const roh = gesehen.get(`${b.quelle}:${b.id}`);
      if (!roh) return null;
      return {
        quelle: roh.quelle,
        id: roh.id,
        titel: roh.titel,
        datum: roh.datum,
        link: roh.link,
        dateityp: roh.dateityp,
        uebereinstimmung: b.uebereinstimmung === 'hoch' ? 'hoch' : 'moeglich',
        begruendung: b.begruendung || '',
        dokumentart: b.dokumentart || undefined,
      };
    })
    .filter((e: any) => e !== null);

  try {
    await sb.from('dokumentensuche_nutzung_log').insert({
      mitarbeiter_email: mitarbeiterEmail,
      suchbegriff: query,
      quellen: gewuenschteQuellen,
    });
  } catch (e) {
    console.error('Nutzungs-Log fehlgeschlagen:', e);
  }

  return json({ ergebnisse, suchschritte, fehler: fehler.length ? fehler : undefined });
});
