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
// Experimentell (2026-09-27, noch nicht mit echten Anhaengen getestet):
// PDF-Textextraktion fuer die optionale "Mail-Anhaenge inhaltlich
// durchsuchen"-Funktion. Nutzt Mozillas pdf.js ueber den Deno-npm-Kompat-
// Layer - unklar, ob das in dieser Runtime zuverlaessig laeuft, deshalb
// grosszuegig try/catch drumherum (siehe extrahierePdfText).
import * as pdfjsLib from 'npm:pdfjs-dist@4.0.379/legacy/build/pdf.mjs';

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
  vorschauBild?: string;
}

// Google-Drive-Suchsyntax verlangt Escaping von Apostrophen im Suchbegriff.
function escapeDriveQuery(text: string): string {
  return text.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
}

// Drive liefert das Vorschaubild standardmaessig sehr klein (~220px, endet
// auf "=s220") - fuer die Lightbox-Grossansicht viel zu unscharf. Dieselbe
// Bild-Adresse akzeptiert aber eine deutlich groessere Grioesenangabe, ohne
// dass ein zusaetzlicher API-Aufruf noetig ist.
function vergroessereThumbnail(url?: string): string | undefined {
  if (!url) return undefined;
  return /=s\d+$/.test(url) ? url.replace(/=s\d+$/, '=s1600') : `${url}=s1600`;
}

// Dateiformat-Filter (Erweiterung: "Alle"/PDF/Google Docs/Google Sheets/Mail/
// Bild) - fuer Drive als harte mimeType-Bedingung, fuer Gmail als Anhang-
// Dateiendungs-Hinweis (siehe sucheGmail). "mail" selbst betrifft nur Gmail
// (der Mailinhalt zaehlt dort immer, unabhaengig von Anhaengen).
const DRIVE_MIME_BEDINGUNG: Record<string, string> = {
  pdf: "mimeType = 'application/pdf'",
  docs: "mimeType = 'application/vnd.google-apps.document'",
  sheets: "mimeType = 'application/vnd.google-apps.spreadsheet'",
  bild: "mimeType contains 'image/'",
};
const GMAIL_DATEIENDUNGEN: Record<string, string[]> = {
  pdf: ['pdf'],
  docs: ['doc', 'docx'],
  sheets: ['xls', 'xlsx'],
  bild: ['jpg', 'jpeg', 'png'],
};

async function sucheDrive(begriff: string, token: string, zeitraumVon?: string, zeitraumBis?: string, dateiformate?: string[]): Promise<RohTreffer[]> {
  const bedingungen = [`fullText contains '${escapeDriveQuery(begriff)}'`, 'trashed = false'];
  if (zeitraumVon) bedingungen.push(`modifiedTime >= '${zeitraumVon}'`);
  if (zeitraumBis) bedingungen.push(`modifiedTime <= '${zeitraumBis}'`);
  if (dateiformate?.length) {
    const mimeBedingungen = dateiformate.map((f) => DRIVE_MIME_BEDINGUNG[f]).filter(Boolean);
    // Wurden ausschliesslich Formate gewaehlt, die es in Drive gar nicht geben
    // kann (aktuell nur "mail"), gibt es absichtlich keine Drive-Treffer.
    if (!mimeBedingungen.length) return [];
    bedingungen.push(`(${mimeBedingungen.join(' or ')})`);
  }
  const params = new URLSearchParams({
    q: bedingungen.join(' and '),
    fields: 'files(id,name,mimeType,modifiedTime,webViewLink,thumbnailLink)',
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
    // Google generiert bei den meisten Dateitypen (PDF/Bild/Docs/Sheets) ein
    // Vorschaubild - reicht fuer eine schnelle Ansicht, ohne die eigentliche
    // Datei/den Tab zu wechseln. Braucht eine aktive Google-Session im
    // Browser zum Laden (kein separater API-Aufruf, einfacher <img src>).
    vorschauBild: vergroessereThumbnail(f.thumbnailLink),
  }));
}

// Base64url (Gmail-Format) -> Bytes.
function base64UrlZuBytes(b64url: string): Uint8Array {
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

async function extrahierePdfText(bytes: Uint8Array): Promise<string> {
  const doc = await pdfjsLib.getDocument({ data: bytes, useWorker: false, isEvalSupported: false }).promise;
  let text = '';
  for (let i = 1; i <= Math.min(doc.numPages, 5) && text.length < 3000; i++) {
    const page = await doc.getPage(i);
    const content = await page.getTextContent();
    text += content.items.map((it: any) => it.str ?? '').join(' ') + '\n';
  }
  return text.slice(0, 3000).trim();
}

// Laedt PDF-Anhaenge einer Nachricht und haengt den extrahierten Text an -
// nur wenn explizit gewuenscht (spuerbar langsamer: pro Anhang ein weiterer
// API-Aufruf + PDF-Parsing).
async function leseAnhaengeText(messageId: string, token: string): Promise<string> {
  const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}?format=full`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return '';
  const msg = await res.json();
  const parts: any[] = msg.payload?.parts || [];
  const pdfTeile = parts.filter((p) => p.mimeType === 'application/pdf' && p.body?.attachmentId);
  const texte = await Promise.all(pdfTeile.slice(0, 3).map(async (teil) => {
    try {
      const anhangRes = await fetch(
        `https://gmail.googleapis.com/gmail/v1/users/me/messages/${messageId}/attachments/${teil.body.attachmentId}`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      if (!anhangRes.ok) return '';
      const anhang = await anhangRes.json();
      const bytes = base64UrlZuBytes(anhang.data);
      return await extrahierePdfText(bytes);
    } catch (e) {
      console.error('PDF-Anhang lesen fehlgeschlagen:', e);
      return '';
    }
  }));
  return texte.filter(Boolean).join('\n---\n');
}

async function sucheGmail(begriff: string, token: string, zeitraumVon?: string, zeitraumBis?: string, papierkorbSpam = false, dateiformate?: string[], anhaengeDurchsuchen = false): Promise<RohTreffer[]> {
  let gmailQuery = begriff;
  if (zeitraumVon) gmailQuery += ` after:${zeitraumVon.slice(0, 10).replace(/-/g, '/')}`;
  if (zeitraumBis) gmailQuery += ` before:${zeitraumBis.slice(0, 10).replace(/-/g, '/')}`;
  if (papierkorbSpam) gmailQuery += ' in:anywhere';
  if (dateiformate?.length && !dateiformate.includes('mail')) {
    const endungen = [...new Set(dateiformate.flatMap((f) => GMAIL_DATEIENDUNGEN[f] || []))];
    gmailQuery += endungen.length
      ? ` has:attachment (${endungen.map((e) => `filename:${e}`).join(' OR ')})`
      : ' has:attachment';
  }
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
    let snippet = msg.snippet || '';
    if (anhaengeDurchsuchen) {
      const anhangText = await leseAnhaengeText(id, token);
      if (anhangText) snippet += '\n[Anhang-Inhalt] ' + anhangText;
    }
    return {
      quelle: 'gmail' as const,
      id: msg.id,
      titel: betreff,
      snippet,
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

function baueSystemPrompt(dokumentarten: string[], suchgenauigkeit: string, dokumentartenFilter?: string[]): string {
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
${dokumentartenFilter?.length ? `5. WICHTIG: Der Nutzer hat den Vorab-Filter "Dokumentart" auf folgende Arten eingeschraenkt: ${dokumentartenFilter.join(', ')}. Nimm in ergebnisse_liefern NUR Treffer auf, die eindeutig zu einer dieser Arten gehoeren, und setze das Feld "dokumentart" bei diesen Treffern immer entsprechend (nicht leer lassen). Alles andere weglassen, auch wenn es sonst thematisch passen wuerde.` : ''}

Antworte ausschliesslich durch Werkzeug-Aufrufe, keinen Fliesstext.`;
}

// "Schnell" (Haiku) / "Ausfuehrlich" (Sonnet) - Umschalter in der Erweiterung.
// Haiku ist spuerbar schneller, aber etwas weniger differenziert bei
// kniffligen Bewertungen - bewusster Geschwindigkeit/Guete-Kompromiss, den
// die Mitarbeiterin/der Mitarbeiter selbst waehlt, nicht wir festlegen.
const MODELL_MAP: Record<string, string> = {
  haiku: 'claude-haiku-4-5-20251001',
  sonnet: 'claude-sonnet-5',
};

async function rufeClaudeMitTools(system: string, messages: any[], modell: string) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': Deno.env.get('ANTHROPIC_API_KEY') ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: modell,
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

  // GET: liefert die admin-gepflegte Dokumentarten-Liste (Vorab-Filter) und
  // die bestehende Lieferanten-Liste aus dem Offertentool (fuer die
  // Datalist-Vorschlaege beim Lieferant-Feld) - kein Google-Login noetig.
  if (req.method === 'GET') {
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const [{ data: arten, error: artenError }, { data: lieferanten, error: lieferantenError }] = await Promise.all([
      sb.from('dokumentensuche_dokumentart').select('name').eq('aktiv', true).order('sortierung'),
      sb.from('lieferant').select('name').is('archiviert_am', null).order('name'),
    ]);
    if (artenError) return json({ error: artenError.message }, 500);
    if (lieferantenError) return json({ error: lieferantenError.message }, 500);
    return json({
      dokumentarten: (arten || []).map((d: any) => d.name),
      lieferanten: (lieferanten || []).map((l: any) => l.name),
    });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Ungueltiger Request-Body (JSON erwartet).' }, 400);
  }

  const {
    query, mitarbeiterEmail, googleAccessToken, quellen, zeitraumVon, zeitraumBis, papierkorbSpam,
    suchgenauigkeit, maxRunden, kunde, lieferant, dokumentarten: dokumentartenFilter, dateiformate, modell,
    anhaengeDurchsuchen,
  } = body ?? {};
  if (!query || typeof query !== 'string') return json({ error: 'query fehlt.' }, 400);
  if (!mitarbeiterEmail || typeof mitarbeiterEmail !== 'string') return json({ error: 'mitarbeiterEmail fehlt.' }, 400);
  if (!googleAccessToken || typeof googleAccessToken !== 'string') return json({ error: 'googleAccessToken fehlt.' }, 400);
  if (!Deno.env.get('ANTHROPIC_API_KEY')) return json({ error: 'ANTHROPIC_API_KEY ist serverseitig nicht gesetzt.' }, 500);

  const gewuenschteQuellen: string[] = Array.isArray(quellen) && quellen.length ? quellen : ['drive', 'gmail'];
  const genauigkeit = ['genau', 'teilwort', 'sinngemaess'].includes(suchgenauigkeit) ? suchgenauigkeit : 'sinngemaess';
  const modellName = MODELL_MAP[modell as string] || MODELL_MAP.sonnet;

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
        treffer = await sucheDrive(input.begriff, googleAccessToken, zeitraumVon, zeitraumBis, dateiformate);
        suchschritte.push({ quelle: 'drive', begriff: input.begriff });
      } else if (name === 'gmail_suchen' && gewuenschteQuellen.includes('gmail')) {
        treffer = await sucheGmail(input.begriff, googleAccessToken, zeitraumVon, zeitraumBis, !!papierkorbSpam, dateiformate, !!anhaengeDurchsuchen);
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

  const dokumentartenFilterListe: string[] | undefined = Array.isArray(dokumentartenFilter) && dokumentartenFilter.length ? dokumentartenFilter : undefined;
  const system = baueSystemPrompt(dokumentarten, genauigkeit, dokumentartenFilterListe);

  const kundeHinweis = typeof kunde === 'string' && kunde.trim()
    ? `\nZusatzhinweis: Der gesuchte Kunde ist "${kunde.trim()}" - beziehe das stark in Suche und Bewertung ein, werte Treffer ohne erkennbaren Bezug dazu als hoechstens "moeglich".`
    : '';

  // Lieferant: falls er in der bestehenden Lieferanten-Tabelle des
  // Offertentools gefunden wird, dessen hinterlegte E-Mail-Adressen als
  // gezielten Gmail-Suchhinweis mitgeben - praeziser als nur der Firmenname.
  let lieferantHinweis = '';
  if (typeof lieferant === 'string' && lieferant.trim()) {
    let emails: string[] = [];
    try {
      const { data: lieferantRow } = await sb.from('lieferant')
        .select('name, kontaktdaten')
        .ilike('name', `%${lieferant.trim()}%`)
        .is('archiviert_am', null)
        .limit(1)
        .maybeSingle();
      emails = (lieferantRow?.kontaktdaten as any)?.emails || [];
    } catch (e) {
      console.error('Lieferanten-Nachschlag fehlgeschlagen:', e);
    }
    lieferantHinweis = emails.length
      ? `\nZusatzhinweis: Der gesuchte Lieferant ist "${lieferant.trim()}", bekannte E-Mail-Adressen: ${emails.join(', ')} - nutze diese gezielt in der Gmail-Suche (z.B. als Suchbegriff "from:${emails[0]}"), und werte Treffer ohne erkennbaren Bezug zu diesem Lieferanten als hoechstens "moeglich".`
      : `\nZusatzhinweis: Der gesuchte Lieferant ist "${lieferant.trim()}" - beziehe das stark in Suche und Bewertung ein, werte Treffer ohne erkennbaren Bezug dazu als hoechstens "moeglich".`;
  }

  const messages: any[] = [{ role: 'user', content: `Suchanfrage: ${query}${kundeHinweis}${lieferantHinweis}` }];

  let bewertungen: any[] = [];
  // Nutzer-waehlbare Sicherheitsbremse (Schnell/Normal/Ausfuehrlich in der
  // Erweiterung) - hart begrenzt, damit eine falsche/manipulierte Eingabe
  // keine beliebig teure Endlosschleife an Claude-Aufrufen ausloesen kann.
  const MAX_RUNDEN = Math.min(10, Math.max(1, Number(maxRunden) || 4));
  for (let runde = 0; runde < MAX_RUNDEN; runde++) {
    const antwort = await rufeClaudeMitTools(system, messages, modellName);
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
  // Zusaetzliche, vom Claude-Verhalten unabhaengige Absicherung: wurde ein
  // Dokumentart-Vorab-Filter gewaehlt, faellt ein Treffer ohne passende
  // Dokumentart auch dann raus, wenn Claude die Prompt-Anweisung missachtet.
  const ergebnisse = bewertungen
    .map((b: any) => {
      const roh = gesehen.get(`${b.quelle}:${b.id}`);
      if (!roh) return null;
      if (dokumentartenFilterListe && !dokumentartenFilterListe.includes(b.dokumentart)) return null;
      return {
        quelle: roh.quelle,
        id: roh.id,
        titel: roh.titel,
        datum: roh.datum,
        link: roh.link,
        dateityp: roh.dateityp,
        vorschauBild: roh.vorschauBild,
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
