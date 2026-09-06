// ============================================================================
// Offertentool 2027 - Mail-Assistent: KI-Entwurf fuers Verfassen/Beantworten.
//
// Wird von der Chrome-Erweiterung aufgerufen (kein Supabase-Login noetig -
// Mitarbeitende haben nur ein Google-Konto, kein Offertentool-Konto). Laeuft
// darum komplett mit dem Service-Role-Key (umgeht RLS), nicht mit dem
// Anon-Key eines eingeloggten Benutzers wie sonst ueblich in diesem Projekt.
//
// Modi (body.modus):
//  - 'verfassen': neue Mail, optional per Vorlage (body.vorlageId) oder frei
//    per Stichworte (body.stichworte).
//  - 'antworten': Antwort auf eine eingehende Mail (body.mailInhalt). Liest
//    Sonderfaelle + Mail-Vorlagen:Antworten + Distanzlogik-Trigger, laesst
//    Claude in einem Schritt entscheiden, was zutrifft:
//      a) direkter Entwurf (matcht eine einfache Vorlage/einen Sonderfall/
//         Auffangfall)
//      b) Rueckfrage noetig (Vorlage vom Typ 'rueckfrage')
//      c) Distanzlogik noetig (Kontaktanfrage-artig) - dann zweiter Schritt:
//         Google-Maps-Distanz -> passende Stufe -> ggf. Partner-Empfehlung
//         -> finaler Entwurf.
//  - 'rueckfrage-antwort': Fortsetzung nach b) - body.vorlageId + body.
//    antwortLabel (gewaehlter Zweig) -> Entwurf mit dem hinterlegten Text
//    dieses Zweigs als Vorlage.
//  - 'nachbessern': body.aktuellerEntwurf + body.anweisung -> ueberarbeiteter
//    Entwurf, Schreibstil bleibt Leitplanke.
//
// Antwort: { aktion: 'entwurf', text, tokensInput, tokensOutput }
//       ODER { aktion: 'rueckfrage', vorlageId, frage, antworten: [{label}], tokensInput, tokensOutput }
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY');
const sb = createClient(supabaseUrl, serviceRoleKey);

// ----------------------------------------------------------------------------
// Anthropic-Aufruf (rohes fetch, kein SDK - gleiches Muster wie bei den
// anderen Edge Functions dieses Projekts, die einen externen LLM per fetch
// aufrufen statt eines SDKs).
// ----------------------------------------------------------------------------
async function rufeClaudeAuf(modell: string, system: string, userText: string, maxTokens = 2000) {
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'x-api-key': anthropicKey ?? '',
      'anthropic-version': '2023-06-01',
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: modell,
      max_tokens: maxTokens,
      system,
      messages: [{ role: 'user', content: userText }],
    }),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error?.message || `Anthropic-Fehler (${res.status})`);
  const text = (data.content || []).map((c: any) => c.text || '').join('');
  return { text, tokensInput: data.usage?.input_tokens ?? 0, tokensOutput: data.usage?.output_tokens ?? 0 };
}

// Extrahiert das erste vollstaendige {...}-JSON-Objekt aus einer Antwort -
// robust gegen den Fall, dass Claude trotz Anweisung noch ein Wort davor/
// danach schreibt.
function extrahiereJson(text: string): any {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1) throw new Error('Keine JSON-Antwort erhalten: ' + text.slice(0, 200));
  return JSON.parse(text.slice(start, end + 1));
}

async function protokolliereNutzung(mitarbeiterEmail: string, richtung: string, vorlageId: string | null, tokensInput: number, tokensOutput: number) {
  await sb.from('mailassistent_nutzung_log').insert({
    mitarbeiter_email: mitarbeiterEmail, richtung, vorlage_id: vorlageId,
    tokens_input: tokensInput, tokens_output: tokensOutput,
  });
}

async function ladeModell(): Promise<string> {
  const { data } = await sb.from('mailassistent_einstellungen').select('anthropic_modell').limit(1).maybeSingle();
  return data?.anthropic_modell || 'claude-sonnet-5';
}

function formatiereFirmendaten(fd: any): string {
  if (!fd) return '';
  return [
    fd.name_kunden && `Firma (Kunden gegenüber): ${fd.name_kunden}`,
    fd.name_rechnungen && `Firma (Rechnungen): ${fd.name_rechnungen}`,
    fd.adresse && `Adresse: ${fd.adresse}`,
    fd.telefon && `Telefon: ${fd.telefon}`,
    fd.web && `Web: ${fd.web}`,
    fd.iban && `IBAN: ${fd.iban}`,
    fd.swift_bic && `SWIFT-BIC: ${fd.swift_bic}`,
  ].filter(Boolean).join('\n');
}

// ----------------------------------------------------------------------------
// Modus: verfassen
// ----------------------------------------------------------------------------
async function modusVerfassen(body: any, modell: string) {
  const [{ data: schreibstil }, { data: firmendaten }] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
  ]);

  let vorlage = null;
  if (body.vorlageId) {
    const { data } = await sb.from('mailassistent_vorlage').select('*').eq('id', body.vorlageId).maybeSingle();
    vorlage = data;
  }

  const teile = [];
  if (schreibstil?.immer_verfassen && schreibstil.inhalt) teile.push('SCHREIBSTIL:\n' + schreibstil.inhalt);
  if (firmendaten?.immer_verfassen) teile.push('FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten));
  if (vorlage) teile.push(`VORLAGE "${vorlage.titel}" - GENAU DIESEN TEXT WORTGETREU UEBERNEHMEN. Nur Platzhalter wie [NAME]/[PROJEKT] mit den Stichworten sinnvoll ersetzen oder offen lassen. KEINEN eigenen Text erfinden, auch nicht wenn die Vorlage kurz oder unklar wirkt:\n${vorlage.inhalt}`);
  if (body.stichworte) teile.push('STICHWORTE VOM MITARBEITER:\n' + body.stichworte);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung, keine Anführungszeichen drumherum.');

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Kunden-/Geschäftsmails zu verfassen.', teile.join('\n\n'), 1500);
  await protokolliereNutzung(body.mitarbeiterEmail, 'verfassen', vorlage?.id ?? null, tokensInput, tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), tokensInput, tokensOutput });
}

// ----------------------------------------------------------------------------
// Modus: antworten (intern) - Express-Pfad fuer Mails von @knechtgarten.ch-
// Kollegen: kein Sonderfaelle/Vorlagen/Distanzlogik-Menu noetig, nur ein
// kurzer Antworttext (Stichworte reichen, siehe Schreibstil). Kleinerer
// Prompt + weniger Output-Tokens = spuerbar schneller und guenstiger als der
// volle Klassifizierungs-Prompt unten.
// ----------------------------------------------------------------------------
async function modusAntwortenIntern(body: any, modell: string) {
  const { data: schreibstil } = await sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle();
  const system = `Du bist der Mail-Assistent von Knechtgarten. Diese Nachricht kommt von einer Kollegin/einem Kollegen (intern), keine Kundenmail.
Antworte kurz und direkt - Stichworte reichen, keine ganzen Saetze noetig. Keine Anrede-Floskeln, ausser sie passen wirklich.
${schreibstil?.immer_antworten && schreibstil.inhalt ? '\nSCHREIBSTIL (soweit fuer interne Mails relevant):\n' + schreibstil.inhalt : ''}
Schreibe direkt den Antworttext. Nur den Mailtext ausgeben, keine Erklaerung, keine Anfuehrungszeichen drumherum.`;

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, system, 'INTERNE NACHRICHT:\n' + body.mailInhalt, 400);
  await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInput, tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), tokensInput, tokensOutput });
}

// ----------------------------------------------------------------------------
// Modus: antworten - Klassifizierung + (wo moeglich) direkter Entwurf in
// einem Schritt.
// ----------------------------------------------------------------------------
async function modusAntworten(body: any, modell: string) {
  if (body.intern) return await modusAntwortenIntern(body, modell);

  const [
    { data: schreibstil }, { data: firmendaten }, { data: sonderfaelle },
    { data: vorlagen }, { data: distanzMeta }, { data: projekttypen },
  ] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_sonderfall').select('*').eq('immer_antworten', true).order('reihenfolge'),
    sb.from('mailassistent_vorlage').select('*, mailassistent_vorlage_antwort(*)').eq('richtung', 'antworten').order('reihenfolge'),
    sb.from('mailassistent_distanzlogik_meta').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_distanz_projekttyp').select('*').order('reihenfolge'),
  ]);

  const sonderfaelleMenu = (sonderfaelle || []).map((sf: any) => {
    const ausnahmen = (sonderfaelle || []).filter((x: any) => x.ist_ausnahme_von === sf.id);
    return `- "${sf.titel}"${sf.ist_auffangfall ? ' [AUFFANGFALL - nur wenn wirklich nichts anderes passt]' : ''}\n  Stichwörter: ${sf.stichwoerter || '–'}\n  Verhalten: ${sf.verhalten || '–'}` +
      (ausnahmen.length ? ausnahmen.map((a: any) => `\n  AUSNAHME "${a.titel}" (${a.stichwoerter || '–'}): ${a.verhalten}`).join('') : '');
  }).join('\n');

  const vorlagenMenu = (vorlagen || []).map((v: any) => {
    if (v.typ === 'rueckfrage') {
      const zweige = (v.mailassistent_vorlage_antwort || []).map((z: any) => z.label).join(' / ');
      return `- VORLAGE "${v.titel}" [MIT RÜCKFRAGE] – trifft zu wenn: ${v.wann_trifft_zu || '–'}\n  Frage an den Mitarbeiter: "${v.frage}"\n  Mögliche Antworten: ${zweige}`;
    }
    return `- VORLAGE "${v.titel}" – trifft zu wenn: ${v.wann_trifft_zu || '–'}\n  Text:\n${v.inhalt}`;
  }).join('\n\n');

  const projekttypenMenu = (projekttypen || []).map((t: any) => `- "${t.titel}": ${t.beschreibung || '–'}`).join('\n');

  const system = `Du bist der Mail-Assistent von Knechtgarten (Gartenbau-Unternehmen, Heimenschwand/BE). Du liest eine eingehende Mail und entscheidest, wie sie beantwortet werden soll.

${schreibstil?.immer_antworten && schreibstil.inhalt ? 'SCHREIBSTIL:\n' + schreibstil.inhalt + '\n\n' : ''}${firmendaten?.immer_antworten ? 'FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten) + '\n\n' : ''}SONDERFÄLLE (prüfe zuerst, ob einer eindeutig zutrifft - Ausnahmen gehen der Hauptregel vor):
${sonderfaelleMenu || '(keine erfasst)'}

MAIL-VORLAGEN:
${vorlagenMenu || '(keine erfasst)'}

DISTANZLOGIK - nur relevant wenn: ${distanzMeta?.wann_anwenden || '(nicht konfiguriert)'}
Falls die Mail eine Kontaktanfrage in diesem Sinn ist, gibt es dafür keine fixe Vorlage - stattdessen muss die Fahrdistanz zum Kunden berechnet werden. Projekttypen zur Einordnung:
${projekttypenMenu || '(keine erfasst)'}

Entscheide jetzt, was zutrifft, und antworte AUSSCHLIESSLICH mit einem JSON-Objekt (kein Text davor/danach), in einer dieser drei Formen:
1. Direkter Entwurf möglich (Sonderfall/einfache Vorlage/Auffangfall):
{"aktion":"entwurf","text":"<fertiger Mailtext>"}
   Trifft eine VORLAGE zu: deren Text WORTGETREU übernehmen, nur Platzhalter wie [Datum, Uhrzeit]/[X Minuten] sinnvoll ausfüllen oder offen lassen - keinen eigenen Text erfinden, auch nicht bei kurzen/unklar wirkenden Vorlagen.
2. Eine Vorlage mit Rückfrage trifft zu:
{"aktion":"rueckfrage","vorlageTitel":"<exakter Titel der Vorlage>"}
3. Distanzlogik trifft zu (Kontaktanfrage):
{"aktion":"distanzlogik","projekttyp":"<exakter Titel des Projekttyps>","kundenAdresse":"<aus der Mail extrahierte Adresse/PLZ+Ort>"}
Wenn bei Fall 3 keine Adresse erkennbar ist, nutze stattdessen den Sonderfall "Kein Ort erkennbar" (Fall 1).`;

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, system, 'EINGEHENDE MAIL:\n' + body.mailInhalt, 2000);
  let entscheidung;
  try { entscheidung = extrahiereJson(text); }
  catch (e) { return json({ error: 'KI-Antwort konnte nicht gelesen werden: ' + String(e) }, 502); }

  if (entscheidung.aktion === 'entwurf') {
    await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInput, tokensOutput);
    return json({ aktion: 'entwurf', text: (entscheidung.text || '').trim(), tokensInput, tokensOutput });
  }

  if (entscheidung.aktion === 'rueckfrage') {
    const vorlage = (vorlagen || []).find((v: any) => v.titel === entscheidung.vorlageTitel);
    if (!vorlage) return json({ error: 'Vorlage "' + entscheidung.vorlageTitel + '" nicht gefunden.' }, 502);
    await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', vorlage.id, tokensInput, tokensOutput);
    return json({
      aktion: 'rueckfrage', vorlageId: vorlage.id, frage: vorlage.frage,
      antworten: (vorlage.mailassistent_vorlage_antwort || []).sort((a: any, b: any) => a.reihenfolge - b.reihenfolge).map((z: any) => ({ label: z.label })),
      tokensInput, tokensOutput,
    });
  }

  if (entscheidung.aktion === 'distanzlogik') {
    return await fuehreDistanzlogikAus(body, modell, entscheidung, schreibstil, firmendaten, projekttypen, tokensInput, tokensOutput);
  }

  return json({ error: 'Unbekannte KI-Entscheidung: ' + JSON.stringify(entscheidung) }, 502);
}

// ----------------------------------------------------------------------------
// Distanzlogik-Unterablauf: Google-Maps-Distanz -> passende Stufe ->
// ggf. Partner-Empfehlung -> finaler Entwurf.
// ----------------------------------------------------------------------------
async function berechneFahrzeitMinuten(origin: string, destination: string): Promise<number | null> {
  const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY');
  if (!apiKey) return null;
  const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destination)}&key=${apiKey}`;
  const res = await fetch(url);
  const data = await res.json();
  const el = data?.rows?.[0]?.elements?.[0];
  if (el?.status !== 'OK') return null;
  return Math.round(el.duration.value / 60);
}

async function fuehreDistanzlogikAus(body: any, modell: string, entscheidung: any, schreibstil: any, firmendaten: any, projekttypen: any[], tokensInputBisher: number, tokensOutputBisher: number) {
  const projekttyp = (projekttypen || []).find((t: any) => t.titel === entscheidung.projekttyp) || projekttypen?.[0];
  if (!projekttyp || !firmendaten?.adresse) {
    return json({ error: 'Distanzlogik nicht möglich (Projekttyp oder Firmenadresse fehlt).' }, 502);
  }
  const minuten = await berechneFahrzeitMinuten(firmendaten.adresse, entscheidung.kundenAdresse);
  if (minuten === null) {
    return json({ error: 'Distanz zu "' + entscheidung.kundenAdresse + '" konnte nicht berechnet werden.' }, 502);
  }

  const { data: stufen } = await sb.from('mailassistent_distanz_stufe').select('*').eq('projekttyp_id', projekttyp.id).order('reihenfolge');
  let stufe = (stufen || []).find((s: any) => s.bis_minuten !== null && minuten <= s.bis_minuten);
  if (!stufe) stufe = (stufen || []).find((s: any) => s.bis_minuten === null) || (stufen || [])[(stufen || []).length - 1];
  if (!stufe) return json({ error: 'Für "' + projekttyp.titel + '" sind keine Stufen erfasst.' }, 502);

  let anweisung = `Verfasse den Entwurf nach folgender Vorgabe: ${stufe.vorlage_text}`;
  if (stufe.ist_partner_logik) {
    const { data: meta } = await sb.from('mailassistent_distanzlogik_meta').select('partner_umkreis_minuten').limit(1).maybeSingle();
    const umkreis = meta?.partner_umkreis_minuten ?? 35;
    const { data: partner } = await sb.from('mailassistent_partnerbetrieb').select('*').order('reihenfolge');
    let naechster: { name: string; adresse: string; minuten: number } | null = null;
    for (const p of partner || []) {
      const m = await berechneFahrzeitMinuten(p.adresse, entscheidung.kundenAdresse);
      if (m !== null && m <= umkreis && (!naechster || m < naechster.minuten)) naechster = { name: p.name, adresse: p.adresse, minuten: m };
    }
    anweisung = naechster
      ? `Der Kunde liegt zu weit weg für ein eigenes Angebot (${minuten} Min. Fahrzeit). Sage höflich ab und empfehle stattdessen den Partnerbetrieb "${naechster.name}" (${naechster.adresse}).`
      : `Der Kunde liegt zu weit weg für ein eigenes Angebot (${minuten} Min. Fahrzeit) und es gibt keinen Partnerbetrieb in der Nähe. Sage höflich ab, ohne einen Partnerbetrieb zu empfehlen.`;
  }

  const teile = [];
  if (schreibstil?.immer_antworten && schreibstil.inhalt) teile.push('SCHREIBSTIL:\n' + schreibstil.inhalt);
  teile.push('FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten));
  teile.push(anweisung);
  teile.push('Berücksichtige die Fahrzeit von ca. ' + minuten + ' Minuten, falls das für den Text relevant ist.');
  teile.push('EINGEHENDE MAIL:\n' + body.mailInhalt);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung.');

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Kundenmails zu verfassen.', teile.join('\n\n'), 1500);
  await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInputBisher + tokensInput, tokensOutputBisher + tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), tokensInput: tokensInputBisher + tokensInput, tokensOutput: tokensOutputBisher + tokensOutput });
}

// ----------------------------------------------------------------------------
// Modus: rueckfrage-antwort - Zweig gewaehlt, jetzt den hinterlegten Text
// dieses Zweigs als Grundlage fuer den echten Entwurf verwenden.
// ----------------------------------------------------------------------------
async function modusRueckfrageAntwort(body: any, modell: string) {
  const [{ data: schreibstil }, { data: firmendaten }, { data: vorlage }] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_vorlage').select('*, mailassistent_vorlage_antwort(*)').eq('id', body.vorlageId).maybeSingle().then(r => r),
  ]);
  const zweig = (vorlage?.mailassistent_vorlage_antwort || []).find((z: any) => z.label === body.antwortLabel);
  if (!zweig) return json({ error: 'Antwort "' + body.antwortLabel + '" nicht gefunden.' }, 502);

  const teile = [];
  if (schreibstil?.immer_antworten && schreibstil.inhalt) teile.push('SCHREIBSTIL:\n' + schreibstil.inhalt);
  if (firmendaten?.immer_antworten) teile.push('FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten));
  teile.push(`VORLAGE - GENAU DIESEN TEXT WORTGETREU UEBERNEHMEN, nur Platzhalter wie [Datum, Uhrzeit] sinnvoll ausfüllen oder offen lassen. KEINEN eigenen Text erfinden:\n${zweig.inhalt}`);
  if (body.mailInhalt) teile.push('EINGEHENDE MAIL:\n' + body.mailInhalt);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung.');

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Mails zu verfassen.', teile.join('\n\n'), 1500);
  await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', body.vorlageId, tokensInput, tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), tokensInput, tokensOutput });
}

// ----------------------------------------------------------------------------
// Modus: nachbessern
// ----------------------------------------------------------------------------
async function modusNachbessern(body: any, modell: string) {
  const { data: schreibstil } = await sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle();
  const teile = [];
  if (schreibstil?.inhalt) teile.push('SCHREIBSTIL (weiterhin einhalten):\n' + schreibstil.inhalt);
  teile.push('BISHERIGER ENTWURF:\n' + body.aktuellerEntwurf);
  teile.push('ANWEISUNG ZUR ÜBERARBEITUNG:\n' + body.anweisung);
  teile.push('Schreibe den überarbeiteten Mailtext. Nur den Mailtext ausgeben, keine Erklärung.');

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du überarbeitest einen Mail-Entwurf für Knechtgarten nach einer Anweisung.', teile.join('\n\n'), 1500);
  await protokolliereNutzung(body.mitarbeiterEmail, body.richtung || 'antworten', body.vorlageId ?? null, tokensInput, tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), tokensInput, tokensOutput });
}

// ----------------------------------------------------------------------------
// Reine Lese-Endpunkte fuer die Erweiterung (Chips/Buttons-Liste) - brauchen
// keinen Mitarbeiter-Namen, da hier nichts protokolliert wird.
// ----------------------------------------------------------------------------
async function modusListeVerfassen() {
  // inhalt+typ werden mitgeliefert, damit die Erweiterung platzhalterfreie
  // einfache Vorlagen direkt einfuegen kann, ganz ohne KI-Aufruf (Express).
  const { data } = await sb.from('mailassistent_vorlage').select('id,titel,typ,inhalt').eq('richtung', 'verfassen').order('reihenfolge');
  return json({ vorlagen: data || [] });
}
async function modusListeNachbessern() {
  const { data } = await sb.from('mailassistent_nachbessern_button').select('id,titel,anweisung').order('reihenfolge');
  return json({ buttons: data || [] });
}

// ----------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => ({}));

    if (body.modus === 'liste-verfassen') return await modusListeVerfassen();
    if (body.modus === 'liste-nachbessern') return await modusListeNachbessern();

    if (!anthropicKey) return json({ error: 'ANTHROPIC_API_KEY ist auf dem Server nicht konfiguriert.' }, 500);
    if (!body.mitarbeiterEmail) return json({ error: 'mitarbeiterEmail ist erforderlich.' }, 400);
    const modell = await ladeModell();

    switch (body.modus) {
      case 'verfassen': return await modusVerfassen(body, modell);
      case 'antworten': return await modusAntworten(body, modell);
      case 'rueckfrage-antwort': return await modusRueckfrageAntwort(body, modell);
      case 'nachbessern': return await modusNachbessern(body, modell);
      default: return json({ error: 'Unbekannter modus: ' + body.modus }, 400);
    }
  } catch (e) {
    console.error(e);
    return json({ error: String(e?.message || e) }, 500);
  }
});
