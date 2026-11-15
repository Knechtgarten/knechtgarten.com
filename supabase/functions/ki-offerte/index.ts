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
import * as XLSX from 'npm:xlsx@0.18.5';

// Zusatzquelle Google Drive: über die Google-Verbindung des Firmenkontos (wie fotos/doku-google),
// nur in der geteilten Ablage «01_Kundendaten / Projekte» (keine Personal-/Buchhaltungsordner).
const GOOGLE_CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';
const FIRMENKONTO = 'mail@knechtgarten.ch';
const DRIVE_KUNDEN = '0AEZm9ALFx3sgUk9PVA';
function zuBase64(bytes: Uint8Array): string {
  let s = ''; const n = 0x8000;
  for (let i = 0; i < bytes.length; i += n) s += String.fromCharCode(...bytes.subarray(i, i + n));
  return btoa(s);
}
const DRIVE_TOOLS: any[] = [
  {
    name: 'drive_suchen',
    description: 'Sucht Dateien in der Google-Drive-Ablage «Kundendaten / Projekte» von Knechtgarten (Volltext in Dateinamen und Inhalt: Pläne, Notizen, Lieferantenofferten, Preislisten, Ausmasse). Liefert id, Name, Typ, Datum, Ordner-Link. Danach mit drive_datei_lesen den Inhalt holen.',
    input_schema: { type: 'object', properties: { suchbegriff: { type: 'string', description: 'kurz, z. B. Kundenname, «Preisliste Däpp», «Ausmass Mauer»' } }, required: ['suchbegriff'], additionalProperties: false },
  },
  {
    name: 'kundenordner_dateien',
    description: 'Listet die Dateien im Drive-Ordner des aktuellen Kunden (alle Jahre, bis 3 Ebenen tief): Notizen, Pläne, Fotos, frühere Offerten. Danach mit drive_datei_lesen den Inhalt holen.',
    input_schema: { type: 'object', properties: {}, additionalProperties: false },
  },
  {
    name: 'drive_datei_lesen',
    description: 'Liest den Inhalt einer Drive-Datei (Google Docs/Tabellen, PDF, Excel, Text, Bilder).',
    input_schema: { type: 'object', properties: { id: { type: 'string' } }, required: ['id'], additionalProperties: false },
  },
];

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
  const quellen: string[] = Array.isArray(body?.quellen) ? body.quellen.map(String) : [];
  const mitInternet = quellen.includes('internet');
  // Zusatzquelle Internet: Websuche von Anthropic (läuft serverseitig), nur wenn der Schalter an ist
  const mitDrive = quellen.includes('drive');
  const tools: any[] = [...TOOLS, ...(mitDrive ? DRIVE_TOOLS : []), ...(mitInternet ? [{ type: 'web_search_20260209', name: 'web_search', max_uses: 5, user_location: { type: 'approximate', country: 'CH', region: 'Bern' } }] : [])];
  const system = SYSTEM
    + (mitDrive ? '\n- Zusatzquelle Drive ist eingeschaltet: Schau mit kundenordner_dateien, was im Ordner dieses Kunden liegt (Notizen, Pläne, Ausmasse von der Besichtigung), und lies Relevantes mit drive_datei_lesen. Mit drive_suchen findest du z. B. Lieferantenofferten oder Preislisten. Erwähnst du eine Datei, schreibe sie als Link [Dateiname](https://drive.google.com/…). Drive-Preise: quelle "vorgabe" wenn es eine Lieferantenofferte für dieses Projekt ist, sonst "geschaetzt", quelle_info = Datei.' : '')
    + (mitInternet ? '\n- Zusatzquelle Internet ist eingeschaltet: Findest du in unseren Quellen nichts Passendes (z. B. Pflanze, Spezialmaterial), suche mit web_search nach Schweizer Listenpreisen (z. B. Baumschulen, Händler). Solche Preise sind Einkaufs-/Listenpreise: quelle "geschaetzt", quelle_info = Händler + Preis, und nenne die Seite in der Antwort als normalen Link [Händler](https://…).' : '');

  const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  // Google-Zugang des Firmenkontos (einmal pro Anfrage)
  let googleToken = '';
  async function google(): Promise<string> {
    if (googleToken) return googleToken;
    const secret = Deno.env.get('GOOGLE_CLIENT_SECRET'); if (!secret) throw new Error('GOOGLE_CLIENT_SECRET fehlt.');
    const { data: fb } = await sb.from('benutzer').select('id').ilike('email', FIRMENKONTO).maybeSingle();
    const { data: gv } = fb ? await sb.from('google_verbindung').select('refresh_token').eq('benutzer_id', fb.id).maybeSingle() : { data: null };
    if (!gv) throw new Error('Das Firmenkonto ist nicht mit Google verbunden.');
    const r = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ refresh_token: gv.refresh_token, client_id: GOOGLE_CLIENT_ID, client_secret: secret, grant_type: 'refresh_token' }) });
    const t = await r.json(); if (!r.ok) throw new Error('Google: ' + (t.error_description || t.error));
    return googleToken = t.access_token;
  }
  async function gdrive(pfad: string): Promise<any> {
    const r = await fetch('https://www.googleapis.com/drive/v3/' + pfad, { headers: { Authorization: 'Bearer ' + await google() } });
    if (!r.ok) throw new Error('Drive (' + r.status + '): ' + (await r.text()).slice(0, 200));
    return r;
  }
  const DATEI_FELDER = 'files(id,name,mimeType,modifiedTime,webViewLink,size,parents)';
  const dateiKurz = (f: any) => ({ id: f.id, name: f.name, typ: f.mimeType, datum: (f.modifiedTime || '').slice(0, 10), link: f.webViewLink });

  async function driveWerkzeug(name: string, input: any): Promise<string | any[]> {
    if (name === 'drive_suchen') {
      const b = String(input?.suchbegriff || '').trim().slice(0, 80).replace(/\\/g, '').replace(/'/g, "\\'");
      if (!b) return 'Kein Suchbegriff.';
      const p = new URLSearchParams({ q: `fullText contains '${b}' and trashed=false and mimeType != 'application/vnd.google-apps.folder'`, corpora: 'drive', driveId: DRIVE_KUNDEN,
        includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: DATEI_FELDER, pageSize: '15', orderBy: 'modifiedTime desc' });
      const d = await (await gdrive('files?' + p)).json();
      return d.files?.length ? JSON.stringify(d.files.map(dateiKurz)) : 'Keine Dateien gefunden.';
    }
    if (name === 'kundenordner_dateien') {
      if (!kunde?.id) return 'Kein Kunde gewählt.';
      const { data: ko } = await sb.from('kunde_ordner').select('drive_id, jahr, name').eq('kunde_id', kunde.id);
      if (!ko?.length) return 'Für diesen Kunden ist kein Drive-Ordner verknüpft.';
      const liste: any[] = [];
      const lesen = async (id: string, pfad: string, tiefe: number) => {
        const p = new URLSearchParams({ q: `'${id}' in parents and trashed=false`, includeItemsFromAllDrives: 'true', supportsAllDrives: 'true', fields: DATEI_FELDER, pageSize: '200' });
        const d = await (await gdrive('files?' + p)).json();
        await Promise.all((d.files || []).map(async (f: any) => {
          if (f.mimeType === 'application/vnd.google-apps.folder') { if (tiefe < 3) await lesen(f.id, pfad + f.name + '/', tiefe + 1); }
          else if (liste.length < 150) liste.push({ ...dateiKurz(f), ordner: pfad });
        }));
      };
      await Promise.all(ko.map((o: any) => lesen(o.drive_id, (o.name || o.jahr || '') + '/', 1)));
      liste.sort((a, b) => b.datum.localeCompare(a.datum));
      return liste.length ? JSON.stringify(liste) : 'Der Kundenordner ist leer.';
    }
    if (name === 'drive_datei_lesen') {
      const id = String(input?.id || '').replace(/[^A-Za-z0-9_-]/g, '');
      const meta = await (await gdrive(`files/${id}?supportsAllDrives=true&fields=id,name,mimeType,size,driveId`)).json();
      if (meta.driveId !== DRIVE_KUNDEN) return 'Diese Datei liegt nicht in der Ablage Kundendaten.';
      const mt = meta.mimeType || '';
      if (mt === 'application/vnd.google-apps.document' || mt === 'application/vnd.google-apps.presentation')
        return `Datei «${meta.name}»:\n` + (await (await gdrive(`files/${id}/export?mimeType=text/plain`)).text()).slice(0, 40000);
      if (mt === 'application/vnd.google-apps.spreadsheet')
        return `Tabelle «${meta.name}» (erstes Blatt, CSV):\n` + (await (await gdrive(`files/${id}/export?mimeType=text/csv`)).text()).slice(0, 40000);
      if (Number(meta.size || 0) > 8_000_000) return `Datei «${meta.name}» ist zu gross zum Lesen (über 8 MB).`;
      const bytes = new Uint8Array(await (await gdrive(`files/${id}?alt=media&supportsAllDrives=true`)).arrayBuffer());
      if (mt === 'application/pdf') return [{ type: 'text', text: `PDF «${meta.name}»:` }, { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: zuBase64(bytes) } }];
      if (/^image\/(jpeg|png|gif|webp)$/.test(mt)) return [{ type: 'text', text: `Bild «${meta.name}»:` }, { type: 'image', source: { type: 'base64', media_type: mt, data: zuBase64(bytes) } }];
      if (/spreadsheetml|ms-excel/.test(mt) || /\.xlsx?$/i.test(meta.name)) {
        const wb = XLSX.read(bytes, { type: 'array' });
        return `Excel «${meta.name}»:\n` + wb.SheetNames.slice(0, 5).map((n: string) => `## ${n}\n` + XLSX.utils.sheet_to_csv(wb.Sheets[n])).join('\n').slice(0, 40000);
      }
      if (/^text\//.test(mt) || /\.(csv|txt)$/i.test(meta.name)) return `Datei «${meta.name}»:\n` + new TextDecoder().decode(bytes).slice(0, 40000);
      return `Datei «${meta.name}» (${mt}) kann ich nicht lesen.`;
    }
    return 'Unbekanntes Werkzeug.';
  }

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
        system,
        tools,
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
      const texte = response.content.filter((b: any) => b.type === 'text').map((b: any) => b.text).join('').trim(); // ohne Zeilenumbruch: mit Websuche (Zitate) kommt ein Satz in mehreren Blöcken
      if (texte) antwort = texte;
      if (response.stop_reason === 'pause_turn') { messages.push({ role: 'assistant', content: response.content }); continue; }
      const aufrufe = response.content.filter((b: any) => b.type === 'tool_use');
      if (response.stop_reason !== 'tool_use' || !aufrufe.length) break;
      messages.push({ role: 'assistant', content: response.content });
      const ergebnisse: any[] = [];
      for (const t of aufrufe) {
        let inhalt: any = '';
        if (t.name === 'blatt_setzen') {
          const z = t.input?.zeilen;
          if (!Array.isArray(z)) inhalt = 'Fehler: zeilen fehlt.';
          else { gesetzt = { zeilen: z.slice(0, 200), arbeitsbeschrieb: typeof t.input?.arbeitsbeschrieb === 'string' ? t.input.arbeitsbeschrieb : null }; inhalt = `Blatt gesetzt (${z.length} Zeilen).`; }
        } else {
          inhalt = ++suchen > 25 ? 'Suchlimit erreicht – nimm, was du gefunden hast, oder schätze (quelle "geschaetzt").' : t.name.startsWith('drive_') || t.name === 'kundenordner_dateien' ? (mitDrive ? await driveWerkzeug(t.name, t.input).catch((e: any) => 'Drive-Fehler: ' + (e?.message || e)) : 'Drive ist nicht eingeschaltet.') : await werkzeug(t.name, t.input);
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
