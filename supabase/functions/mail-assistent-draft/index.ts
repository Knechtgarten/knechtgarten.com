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
//    Mail-Vorlagen:Antworten + Unterkategorien + Distanzlogik-Trigger, laesst
//    Claude in einem Schritt entscheiden, was zutrifft:
//      a) direkter Entwurf (matcht eine einfache Vorlage/Auffangfall)
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

// Die Erweiterung wandelt diese einfache Markdown-Teilmenge beim Einfuegen in
// echte Gmail-Formatierung um (fett/kursiv/Listen) - darum darf/soll die KI
// das gezielt einsetzen, wo es dem Text wirklich hilft.
const KG_FORMAT_HINWEIS = ' Formatierung erlaubt und wird korrekt dargestellt: **fett**, *kursiv*, "- " am Zeilenanfang fuer Aufzaehlungen, "1. " fuer nummerierte Listen - sparsam einsetzen, nur wo es dem Text wirklich hilft.';

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

// Streamende Variante fuer Schritte, bei denen die KI im Wesentlichen eine
// schon feststehende Vorlage nur noch leicht anpasst (z.B. rueckfrage-
// antwort) - der fertige Text erscheint dadurch beim Mitarbeiter Wort fuer
// Wort, statt dass er auf den kompletten Block warten muss. Nutzt Anthropics
// SSE-Streaming (stream:true), reicht jeden Text-Chunk sofort per onChunk
// weiter und gibt am Ende die Token-Zahlen fuers Protokoll zurueck.
async function rufeClaudeAufStreamend(modell: string, system: string, userText: string, maxTokens: number, onChunk: (text: string) => void) {
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
      stream: true,
    }),
  });
  if (!res.ok || !res.body) {
    const data = await res.json().catch(() => ({}));
    throw new Error(data?.error?.message || `Anthropic-Fehler (${res.status})`);
  }
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let puffer = '';
  let tokensInput = 0, tokensOutput = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    puffer += decoder.decode(value, { stream: true });
    const ereignisse = puffer.split('\n\n');
    puffer = ereignisse.pop() ?? '';
    for (const ereignis of ereignisse) {
      const datenzeile = ereignis.split('\n').find((z) => z.startsWith('data:'));
      if (!datenzeile) continue;
      let event: any;
      try { event = JSON.parse(datenzeile.slice(5).trim()); } catch { continue; }
      if (event.type === 'content_block_delta' && event.delta?.type === 'text_delta') {
        onChunk(event.delta.text);
      } else if (event.type === 'message_start') {
        tokensInput = event.message?.usage?.input_tokens ?? 0;
      } else if (event.type === 'message_delta') {
        tokensOutput = event.usage?.output_tokens ?? tokensOutput;
      }
    }
  }
  return { tokensInput, tokensOutput };
}

// Extrahiert das erste vollstaendige {...}-JSON-Objekt aus einer Antwort -
// robust gegen den Fall, dass Claude trotz Anweisung noch ein Wort davor/
// danach schreibt.
function extrahiereJson(text: string): any {
  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1) throw new Error('Keine JSON-Antwort erhalten: ' + text.slice(0, 200));
  // Kein schliessendes "}" gefunden (oder vor dem "{") - die Antwort wurde
  // vermutlich mitten im Satz abgeschnitten (Token-Limit erreicht).
  if (end === -1 || end < start) throw new Error('ABGESCHNITTEN');
  try {
    return JSON.parse(text.slice(start, end + 1));
  } catch (e) {
    throw new Error('ABGESCHNITTEN');
  }
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
  const [{ data: schreibstil }, { data: firmendaten }, { data: faelle }] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_faelle_abschnitt').select('titel,inhalt').order('reihenfolge'),
  ]);

  let vorlage = null;
  if (body.vorlageId) {
    const { data } = await sb.from('mailassistent_vorlage').select('*').eq('id', body.vorlageId).maybeSingle();
    vorlage = data;
  }

  const faelleText = (faelle || [])
    .filter((a: any) => a.inhalt && a.inhalt.trim())
    .map((a: any) => `${a.titel}:\n${a.inhalt}`)
    .join('\n\n');

  const teile = [];
  if (schreibstil?.immer_verfassen && schreibstil.inhalt) teile.push('SCHREIBSTIL:\n' + schreibstil.inhalt);
  if (firmendaten?.immer_verfassen) teile.push('FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten));
  if (faelleText) teile.push('FÄLLE (situative Regeln, gelten immer):\n' + faelleText);
  if (vorlage) teile.push(`VORLAGE "${vorlage.titel}" - GENAU DIESEN TEXT WORTGETREU UEBERNEHMEN, nur die Platzhalter behandeln. KEINEN eigenen Text erfinden, auch nicht wenn die Vorlage kurz oder unklar wirkt.
Platzhalter in eckigen Klammern (z.B. [NAME], [PROJEKT]):
- Einen Platzhalter der Form [ZF:...] sowie JEDEN Platzhalter mit dem Wort "Datum" darin IMMER exakt unveraendert stehen lassen.
- Jeden ANDEREN Platzhalter: kannst du ihn aus den Stichworten des Mitarbeiters sinnvoll ersetzen, tu das in DOPPELTEN eckigen Klammern, z.B. wird aus [NAME] -> [[Herr Müller]] (macht sichtbar, wo du etwas eingesetzt hast, der Mitarbeiter kann es noch per Klick anpassen). Sonst lass ihn unveraendert in einfachen eckigen Klammern stehen.
- Text OHNE Klammern in der VORLAGE (z.B. schon konkrete Namen, Adressen, Telefonnummern, E-Mail-Adressen) bleibt IMMER exakt unveraendert stehen - erstelle NIEMALS neue eckige Klammern um bereits konkrete Angaben.
VORLAGE:\n${vorlage.inhalt}`);
  if (body.stichworte) teile.push('STICHWORTE VOM MITARBEITER:\n' + body.stichworte);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung, keine Anführungszeichen drumherum.' + KG_FORMAT_HINWEIS);

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Kunden-/Geschäftsmails zu verfassen.', teile.join('\n\n'), 2500);
  await protokolliereNutzung(body.mitarbeiterEmail, 'verfassen', vorlage?.id ?? null, tokensInput, tokensOutput);
  return json({ aktion: 'entwurf', text: text.trim(), betreff: vorlage?.betreff || null, tokensInput, tokensOutput });
}

// ----------------------------------------------------------------------------
// Modus: antworten (intern) - Express-Pfad fuer Mails von @knechtgarten.ch-
// Kollegen: kein Vorlagen/Distanzlogik-Menu noetig, nur ein
// kurzer Antworttext (Stichworte reichen, siehe Schreibstil). Kleinerer
// Prompt + weniger Output-Tokens = spuerbar schneller und guenstiger als der
// volle Klassifizierungs-Prompt unten.
// ----------------------------------------------------------------------------
async function modusAntwortenIntern(body: any, modell: string) {
  const { data: schreibstil } = await sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle();
  const system = `Du bist der Mail-Assistent von Knechtgarten. Diese Nachricht kommt von einer Kollegin/einem Kollegen (intern), keine Kundenmail.
Antworte extrem kurz und direkt, wie eine knappe Chat-Nachricht unter Kollegen - z.B. "Ist ok, mache ich.", "Ja, passt.", "Nein, lieber am Montag.". KEINE Anrede ("Hallo ..."), KEINE Grussformel/Verabschiedung ("Freundliche Gruesse" o.ae.), KEINE Floskeln ("Vielen Dank fuer deine Nachricht" o.ae.) - nur die eigentliche Information/Antwort, sonst nichts.
${schreibstil?.immer_antworten && schreibstil.inhalt ? '\nSCHREIBSTIL (nur soweit auch fuer knappe interne Chat-Nachrichten sinnvoll - Anrede/Gruss aus dem Schreibstil hier NICHT uebernehmen):\n' + schreibstil.inhalt : ''}
Schreibe direkt den Antworttext. Nur den Mailtext ausgeben, keine Erklaerung, keine Anfuehrungszeichen drumherum.${KG_FORMAT_HINWEIS}`;

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
    { data: schreibstil }, { data: firmendaten },
    { data: vorlagen }, { data: kundenanfrageVorlagen }, { data: distanzMeta }, { data: faelle },
    { data: mitarbeitende }, { data: externeKontakte }, { data: unterkategorien },
  ] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_vorlage').select(`*, mailassistent_vorlage_antwort(*),
      mailassistent_vorlage_zusatzfenster(
        mailassistent_zusatzfenster(id,typ,titel,platzhalter,erlaubt_eigene_eingabe,zeigt_anzahl,
          mailassistent_zusatzfenster_spalte(id,titel,typ,einheit,platzhalter,breite,reihenfolge,
            mailassistent_zusatzfenster_spalte_option(id,wert,reihenfolge)),
          mailassistent_zusatzfenster_position(id,titel,reihenfolge)))`)
      .eq('richtung', 'antworten').eq('aktiv', true).order('reihenfolge'),
    sb.from('mailassistent_vorlage').select(`*,
      mailassistent_vorlage_zusatzfenster(
        mailassistent_zusatzfenster(id,typ,titel,platzhalter,erlaubt_eigene_eingabe,zeigt_anzahl,
          mailassistent_zusatzfenster_spalte(id,titel,typ,einheit,platzhalter,breite,reihenfolge,
            mailassistent_zusatzfenster_spalte_option(id,wert,reihenfolge)),
          mailassistent_zusatzfenster_position(id,titel,reihenfolge)))`)
      .eq('richtung', 'kundenanfrage').eq('aktiv', true).order('reihenfolge'),
    sb.from('mailassistent_distanzlogik_meta').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_faelle_abschnitt').select('titel,inhalt').order('reihenfolge'),
    sb.from('mailassistent_mitarbeiter').select('name,email,funktion').order('reihenfolge'),
    sb.from('mailassistent_externe_kontakte').select('firma,domains,rolle,notiz').order('reihenfolge'),
    sb.from('mailassistent_unterkategorie').select('*, mailassistent_kategorie(titel)').eq('aktionstyp', 'rueckfrage'),
  ]);

  const mitarbeitendeListe = (mitarbeitende || [])
    .map((m: any) => `${m.name}${m.email ? ' <' + m.email + '>' : ''}${m.funktion ? ' - ' + m.funktion : ''}`)
    .join('\n');
  const externeKontakteListe = (externeKontakte || [])
    .map((k: any) => `${k.firma} (${k.domains})${k.rolle ? ' - ' + k.rolle : ''}${k.notiz ? ' - ' + k.notiz : ''}`)
    .join('\n');
  const faelleText = (faelle || [])
    .filter((a: any) => a.inhalt && a.inhalt.trim())
    .map((a: any) => `${a.titel}:\n${a.inhalt}`)
    .join('\n\n');

  const vorlagenMenu = (vorlagen || []).map((v: any) => {
    if (v.unterkategorie_id) return null; // gehoert zu einer UNTERKATEGORIE unten, nicht einzeln listen
    if (v.typ === 'rueckfrage') {
      const zweige = (v.mailassistent_vorlage_antwort || []).map((z: any) => z.label).join(' / ');
      return `- VORLAGE "${v.titel}" [MIT RÜCKFRAGE] – trifft zu wenn: ${v.wann_trifft_zu || '–'}\n  Frage an den Mitarbeiter: "${v.frage}"\n  Mögliche Antworten: ${zweige}`;
    }
    return `- VORLAGE "${v.titel}" – trifft zu wenn: ${v.wann_trifft_zu || '–'}${v.nicht_anwenden_bei ? `\n  NICHT anwenden bei: ${v.nicht_anwenden_bei}` : ''}\n  Text:\n${v.inhalt}`;
  }).filter(Boolean).join('\n\n');

  const unterkategorienMenu = (unterkategorien || []).map((u: any) => {
    const zugehoerig = (vorlagen || []).filter((v: any) => v.unterkategorie_id === u.id);
    const optionen = zugehoerig.map((v: any) => v.titel).join(' / ');
    return `- UNTERKATEGORIE "${u.titel}" (Kategorie: ${u.mailassistent_kategorie?.titel || '–'}) – zutreffend, wenn die Mail zu diesem Fall gehoert und mehrere gleichwertige Antworten in Frage kommen.` +
      (u.anwenden_bei ? `\n  Anwenden bei: ${u.anwenden_bei}` : '') +
      (u.nicht_anwenden_bei ? `\n  NICHT anwenden bei: ${u.nicht_anwenden_bei}` : '') +
      `\n  Mögliche Antworten: ${optionen || '(keine Vorlagen erfasst)'}`;
  }).join('\n');

  const system = `Du bist der Mail-Assistent von Knechtgarten (Gartenbau-Unternehmen, Heimenschwand/BE). Du liest eine eingehende Mail und entscheidest, wie sie beantwortet werden soll.

${schreibstil?.immer_antworten && schreibstil.inhalt ? 'SCHREIBSTIL:\n' + schreibstil.inhalt + '\n\n' : ''}${firmendaten?.immer_antworten ? 'FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten) + '\n\n' : ''}${mitarbeitendeListe ? 'MITARBEITENDE (unser eigenes Team - gehoert zu "uns", nicht zur Gegenseite):\n' + mitarbeitendeListe + '\n\n' : ''}${externeKontakteListe ? 'BEKANNTE EXTERNE FIRMEN (anhand der Domain im Mailkopf zuordenbar - gehoeren NICHT zu uns):\n' + externeKontakteListe + '\n\n' : ''}${faelleText ? 'FÄLLE (situative Regeln, gelten immer):\n' + faelleText + '\n\n' : ''}Pruefe die folgenden drei Bereiche mit GLEICHER Prioritaet (keiner geht den anderen automatisch vor) - MAIL-VORLAGEN und UNTERKATEGORIEN sind fuer spezifische, bekannte Faelle, KUNDENANFRAGEN ist der Auffangbereich fuer echte Neukunden-/Projektanfragen, die keine dieser spezifischen Vorlagen treffen:

MAIL-VORLAGEN:
${vorlagenMenu || '(keine erfasst)'}

UNTERKATEGORIEN MIT MEHREREN GLEICHWERTIGEN ANTWORTEN - hier gibt es KEINE feste Vorlage, der Mitarbeiter waehlt selbst manuell die passende Antwort aus der Liste der Unterkategorie:
${unterkategorienMenu || '(keine erfasst)'}

KUNDENANFRAGEN - dafür gibt es KEINE feste Vorlage, der Mitarbeiter wählt selbst manuell die passende Antwort aus einer Liste, du lieferst nur die Einordnung + falls möglich die Kundenadresse. Nur relevant wenn: ${distanzMeta?.wann_anwenden || '(nicht konfiguriert)'}

Entscheide jetzt, was zutrifft, und antworte AUSSCHLIESSLICH mit einem JSON-Objekt (kein Text davor/danach), in einer dieser fünf Formen:
1. Direkter Entwurf möglich (einfache Vorlage/Auffangfall):
{"aktion":"entwurf","text":"<fertiger Mailtext>","vorlageTitel":"<exakter Titel der verwendeten VORLAGE, sonst null>"}
   Trifft eine VORLAGE zu: deren Text als starke Richtschnur nehmen (Kernaussage/Entscheidung und Aufbau bleiben, das ist nicht verhandelbar), aber natürlich personalisieren - Namen der Person ansprechen, wo sinnvoll kurz auf Details aus der eingehenden Mail eingehen. Nicht stur wortwörtlich abschreiben, aber auch nichts an der eigentlichen Entscheidung/Aussage ändern. WICHTIG: Waehle eine VORLAGE fuer Fall 1 nur, wenn sie auch wirklich einen "Text:" hat. Hat die naheliegendste VORLAGE (noch) keinen Text hinterlegt, ist sie fuer Fall 1 nicht nutzbar - pruefe stattdessen, ob KUNDENANFRAGEN (Fall 3) zutrifft, oder schreibe selbst einen passenden, kurzen Text (wie bei einem Auffangfall). Erzeuge NIE einen leeren oder nur aus Platzhaltern bestehenden Text.
   Platzhalter in eckigen Klammern (z.B. [Bauteil], [X Minuten]) werden so behandelt:
   - Einen Platzhalter der Form [ZF:...] IMMER exakt unveraendert stehen lassen (nicht ausfuellen, nicht entfernen, nicht uebersetzen) - der wird danach automatisch ersetzt.
   - JEDEN Platzhalter, der das Wort "Datum" enthaelt (z.B. [Datum], [Datum, Uhrzeit]), IMMER exakt unveraendert stehen lassen - der wird separat behandelt.
   - Jeden ANDEREN Platzhalter: kannst du aus der eingehenden Mail/dem Kontext einen konkreten, sinnvollen Wert ableiten, ersetze ihn durch diesen Wert in DOPPELTEN eckigen Klammern, z.B. wird aus [Bauteil] -> [[Ablaufventil]] (macht sichtbar, wo du etwas eingesetzt hast, der Mitarbeiter kann es noch per Klick anpassen). Bist du dir nicht sicher oder fehlt die Information, lass ihn stattdessen unveraendert in einfachen eckigen Klammern stehen, z.B. [Bauteil]. Erfinde NIE einen Wert, den du nicht wirklich aus dem Kontext hast.
   - Text OHNE Klammern in der VORLAGE (z.B. schon konkrete Namen, Adressen, Telefonnummern, E-Mail-Adressen) bleibt IMMER exakt unveraendert stehen - erstelle NIEMALS neue eckige Klammern um bereits konkrete Angaben.
   "vorlageTitel" ist der exakte Titel der VORLAGE, deren Text du als Grundlage genommen hast - null, falls du dir den Text selbst ueberlegt hast (Auffangfall ohne passende VORLAGE).
   Schreibst du den Text selbst (kein VORLAGE-Text als Basis, z.B. Auffangfall oder eine noch nicht erfasste Situation):
   - Beachte dabei insbesondere die oben unter FÄLLE aufgefuehrten Regeln zu Vollstaendigkeit, Personen-Rollen und Danke-Regel.
   - Wird eine konkrete Sachfrage gestellt, die NUR das Team selbst beantworten kann (z.B. "Habt ihr noch X im Einsatz?", "Wie viele Y?", ein internes Detail, das nicht aus der eingehenden Mail hervorgeht) - erfinde NIEMALS eine Antwort darauf. Setze stattdessen einen Platzhalter in eckigen Klammern ein, der kurz beschreibt, was einzusetzen ist, z.B. [Antwort: eigene Space 2.0-Einheiten im Einsatz?] - der Mitarbeiter kann per Klick draufantworten, bevor die Mail rausgeht.
2. Eine Vorlage mit Rückfrage trifft zu:
{"aktion":"rueckfrage","vorlageTitel":"<exakter Titel der Vorlage>"}
3. Es ist eine KUNDENANFRAGE (siehe Bedingung oben):
{"aktion":"kundenanfrage","kundenAdresse":"<Standort des Kunden, sonst null>"}
"kundenAdresse" wird nur für die Distanzberechnung als Zusatz-Info für den Mitarbeiter gebraucht - suche aktiv danach im GANZEN Mailtext UND in einer eventuellen Signatur (Adresszeile, Firmenname mit Ort, o.ä.). Es reicht jede Form von Standortangabe, so genau wie vorhanden:
- Volle Adresse, z.B. "Bernstrasse 12, 3672 Oberdiessbach"
- Nur PLZ+Ort, z.B. "3600 Thun"
- Nur ein Ortsname im Fliesstext, z.B. "wir wohnen in Interlaken" oder "unser Grundstück in Steffisburg" -> "Interlaken" bzw. "Steffisburg"
Nimm exakt das, was in der Mail steht (keine eigene Umformung/Ergänzung, nichts dazu erfinden). Triff dazu KEINE eigene Einschätzung oder Entscheidung - das macht der Mitarbeiter selbst anhand der angezeigten Distanz. Nur wenn wirklich gar kein Hinweis auf einen Standort vorhanden ist, setze null.
4. AUSNAHMEFALL - zwei (normalerweise nicht mehr) einfache VORLAGEN passen ungefähr GLEICH GUT, sagen inhaltlich aber unterschiedliche Dinge aus, und es ist fuer die Antwort wirklich wichtig, welche davon stimmt:
{"aktion":"auswahl","frage":"<kurze, konkrete Frage an den Mitarbeiter, z.B. 'Geht es eher um X oder um Y?'>","vorlagenTitel":["<exakter Titel Vorlage A>","<exakter Titel Vorlage B>"]}
   Nutze Fall 4 NUR SELTEN, bei echter und relevanter Unsicherheit zwischen zwei VORLAGEN. Beim Abwaegen NUR zwischen Fall 1 und Fall 4 im Zweifel Fall 1 waehlen (diese Regel gilt nicht fuer die Wahl zwischen Fall 1 und Fall 3 - dort entscheidet allein, ob die KUNDENANFRAGEN-Bedingung zutrifft und eine passende VORLAGE mit Text existiert).
5. Eine UNTERKATEGORIE MIT MEHREREN GLEICHWERTIGEN ANTWORTEN trifft zu (siehe oben):
{"aktion":"unterkategorie","unterkategorieTitel":"<exakter Titel der Unterkategorie>"}
   Nutze das NUR, wenn wirklich eine der oben gelisteten UNTERKATEGORIEN zutrifft - nicht fuer normale einfache VORLAGEN (dafuer Fall 1) und nicht fuer KUNDENANFRAGEN (dafuer Fall 3).
${KG_FORMAT_HINWEIS}`;

  let userText = 'EINGEHENDE MAIL:\n' + body.mailInhalt;
  if (body.stichworte) userText += '\n\nZUSAETZLICHE STICHWORTE/ANWEISUNG VOM MITARBEITER - unbedingt beruecksichtigen: ' + body.stichworte;
  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, system, userText, 3500);
  let entscheidung;
  try { entscheidung = extrahiereJson(text); }
  catch (e) {
    const abgeschnitten = String(e).includes('ABGESCHNITTEN');
    return json({ error: abgeschnitten
      ? 'Die Antwort wurde beim Erstellen abgeschnitten (zu lang). Bitte nochmal versuchen.'
      : 'KI-Antwort konnte nicht gelesen werden: ' + String(e) }, 502);
  }

  if (entscheidung.aktion === 'entwurf') {
    if (!(entscheidung.text || '').trim()) {
      return json({ error: 'Die KI hat einen leeren Entwurf geliefert - vermutlich hat die gewaehlte Vorlage ("' + (entscheidung.vorlageTitel || '–') + '") noch keinen Text hinterlegt. Bitte Vorlage ergaenzen oder nochmal versuchen.' }, 502);
    }
    let vorlage = null;
    if (entscheidung.vorlageTitel) {
      const gesucht = String(entscheidung.vorlageTitel).trim().toLowerCase();
      vorlage = (vorlagen || []).find((v: any) => v.titel === entscheidung.vorlageTitel)
        || (vorlagen || []).find((v: any) => (v.titel || '').trim().toLowerCase() === gesucht);
      if (!vorlage) {
        return json({ error: 'Vorlage "' + entscheidung.vorlageTitel + '" wurde nicht gefunden (Titel stimmt nicht exakt mit der Verwaltung ueberein) - dadurch waere z.B. ein zugehoeriges Zusatzfenster verloren gegangen. Bitte nochmal versuchen oder den Vorlagen-Titel in der Verwaltung pruefen.' }, 502);
      }
    }
    const zusatzfenster = (vorlage?.mailassistent_vorlage_zusatzfenster || [])
      .map((e: any) => e.mailassistent_zusatzfenster).filter(Boolean);
    await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', vorlage?.id ?? null, tokensInput, tokensOutput);
    return json({
      aktion: 'entwurf', text: (entscheidung.text || '').trim(), vorlageId: vorlage?.id ?? null,
      zusatzfenster: zusatzfenster.length ? zusatzfenster : undefined,
      tokensInput, tokensOutput,
    });
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

  if (entscheidung.aktion === 'kundenanfrage') {
    const distanz = entscheidung.kundenAdresse
      ? await berechneDistanzInfo(entscheidung.kundenAdresse, firmendaten, distanzMeta?.partner_umkreis_minuten ?? 35)
      : null;
    await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInput, tokensOutput);
    return json({
      aktion: 'kundenanfrage',
      antworten: (kundenanfrageVorlagen || []).map((v: any) => ({
        id: v.id, label: v.titel,
        zusatzfenster: (v.mailassistent_vorlage_zusatzfenster || []).map((e: any) => e.mailassistent_zusatzfenster).filter(Boolean),
      })),
      distanz, kundenStandort: distanz?.aufgeloesterStandort || entscheidung.kundenAdresse || null,
      distanzErklaerung: distanzMeta?.distanz_erklaerung || null, hinweistext: distanzMeta?.partner_hinweistext || null,
      eigeneAbsageText: distanzMeta?.absage_text || null,
      tokensInput, tokensOutput,
    });
  }

  if (entscheidung.aktion === 'auswahl' && Array.isArray(entscheidung.vorlagenTitel)) {
    const kandidaten = entscheidung.vorlagenTitel
      .map((t: string) => (vorlagen || []).find((v: any) => v.titel === t))
      .filter(Boolean);
    if (kandidaten.length >= 2) {
      await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInput, tokensOutput);
      return json({
        aktion: 'auswahl', frage: entscheidung.frage || 'Welche Vorlage passt besser?',
        antworten: kandidaten.map((v: any) => ({ label: v.titel })),
        tokensInput, tokensOutput,
      });
    }
  }

  if (entscheidung.aktion === 'unterkategorie') {
    const unterkategorie = (unterkategorien || []).find((u: any) => u.titel === entscheidung.unterkategorieTitel);
    if (!unterkategorie) return json({ error: 'Unterkategorie "' + entscheidung.unterkategorieTitel + '" nicht gefunden.' }, 502);
    const kandidaten = (vorlagen || []).filter((v: any) => v.unterkategorie_id === unterkategorie.id);
    await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', null, tokensInput, tokensOutput);
    return json({
      aktion: 'unterkategorie', titel: unterkategorie.titel,
      antworten: kandidaten.map((v: any) => ({
        id: v.id, label: v.titel,
        zusatzfenster: (v.mailassistent_vorlage_zusatzfenster || []).map((e: any) => e.mailassistent_zusatzfenster).filter(Boolean),
      })),
      tokensInput, tokensOutput,
    });
  }

  return json({ error: 'Unbekannte KI-Entscheidung: ' + JSON.stringify(entscheidung) }, 502);
}

// ----------------------------------------------------------------------------
// Distanz-Infos fuer Kundenanfragen: nur Fahrzeit/Distanz zu Knechtgarten und
// zu allen Partnerbetrieben berechnen, als reine Entscheidungshilfe fuer den
// Mitarbeiter - keine automatische Vorlagen-Auswahl mehr.
// ----------------------------------------------------------------------------
async function berechneDistanz(origin: string, destination: string): Promise<{ minuten: number; km: number; aufgeloesteAdresse: string | null } | null> {
  const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY');
  if (!apiKey) return null;
  const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destination)}&key=${apiKey}`;
  const res = await fetch(url);
  const data = await res.json();
  const el = data?.rows?.[0]?.elements?.[0];
  if (el?.status !== 'OK') return null;
  // destination_addresses liefert die von Google AUFGELOESTE Adresse (z.B.
  // aus einer blossen PLZ wird "8636 Wald ZH") - praktisch, um dem
  // Mitarbeiter mehr als nur die rohe KI-Erkennung zu zeigen, ganz ohne
  // zusaetzlichen API-Aufruf (steckt schon in dieser Antwort mit drin).
  const rohAdresse = data?.destination_addresses?.[0] || null;
  const aufgeloesteAdresse = rohAdresse ? String(rohAdresse).replace(/,\s*(Schweiz|Switzerland)\s*$/i, '') : null;
  return { minuten: Math.round(el.duration.value / 60), km: Math.round(el.distance.value / 1000), aufgeloesteAdresse };
}

async function berechneDistanzInfo(kundenAdresse: string, firmendaten: any, partnerUmkreisMinuten: number) {
  const ergebnis: any = {};
  let aufgeloesterStandort: string | null = null;
  if (firmendaten?.adresse) {
    const eigene = await berechneDistanz(firmendaten.adresse, kundenAdresse);
    if (eigene) { ergebnis.eigene = { minuten: eigene.minuten, km: eigene.km }; aufgeloesterStandort = eigene.aufgeloesteAdresse; }
  }
  const { data: partnerbetriebe } = await sb.from('mailassistent_partnerbetrieb').select('*').order('reihenfolge');
  const partner = [];
  for (const p of partnerbetriebe || []) {
    const d = await berechneDistanz(p.adresse, kundenAdresse);
    if (d) {
      partner.push({ id: p.id, name: p.name, weiterleitungText: p.weiterleitung_text || null, minuten: d.minuten, km: d.km });
      if (!aufgeloesterStandort) aufgeloesterStandort = d.aufgeloesteAdresse;
    }
  }
  // Der naechstgelegene Partnerbetrieb wird nur hervorgehoben, wenn er auch
  // wirklich "in der Naehe" ist (Schwellenwert) - sonst wirkt der naheste
  // von drei weit entfernten Partnerbetrieben wie eine gute Option, obwohl
  // keiner davon tatsaechlich nah ist. Liegt keiner innerhalb der Schwelle,
  // wird gar keiner hervorgehoben.
  const inDerNaehe = partner.filter(p => p.minuten <= partnerUmkreisMinuten);
  const naechster = inDerNaehe.length ? inDerNaehe.reduce((a, b) => (a.minuten <= b.minuten ? a : b)) : null;
  ergebnis.partner = partner;
  ergebnis.naechsterPartnerId = naechster?.id || null;
  ergebnis.aufgeloesterStandort = aufgeloesterStandort;
  return ergebnis;
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
  teile.push(`VORLAGE - als starke Richtschnur nehmen (Kernaussage/Entscheidung und Aufbau bleiben, das ist nicht verhandelbar), aber natürlich personalisieren: Namen der Person ansprechen, wo sinnvoll kurz auf Details aus der eingehenden Mail eingehen. Nicht stur wortwörtlich abschreiben, aber auch nichts an der eigentlichen Entscheidung/Aussage ändern.
Platzhalter in eckigen Klammern (z.B. [Bauteil], [X Minuten]) werden so behandelt:
- Einen Platzhalter der Form [ZF:...] IMMER exakt unveraendert stehen lassen - der wird danach automatisch ersetzt.
- JEDEN Platzhalter, der das Wort "Datum" enthaelt (z.B. [Datum], [Datum, Uhrzeit]), IMMER exakt unveraendert stehen lassen - der wird separat behandelt.
- Jeden ANDEREN Platzhalter: kannst du aus der eingehenden Mail/dem Kontext einen konkreten, sinnvollen Wert ableiten, ersetze ihn durch diesen Wert in DOPPELTEN eckigen Klammern, z.B. wird aus [Bauteil] -> [[Ablaufventil]]. Bist du dir nicht sicher, lass ihn stattdessen unveraendert in einfachen eckigen Klammern stehen. Erfinde NIE einen Wert, den du nicht wirklich aus dem Kontext hast.
- Text OHNE Klammern in der VORLAGE (z.B. schon konkrete Namen, Adressen, Telefonnummern, E-Mail-Adressen) bleibt IMMER exakt unveraendert stehen - erstelle NIEMALS neue eckige Klammern um bereits konkrete Angaben, auch nicht um sie "generischer" oder "vorlagenhafter" wirken zu lassen.
VORLAGE:\n${zweig.inhalt}`);
  if (body.mailInhalt) teile.push('EINGEHENDE MAIL:\n' + body.mailInhalt);
  if (body.anweisung) teile.push('ZUSAETZLICHE ANWEISUNG: ' + body.anweisung);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung.' + KG_FORMAT_HINWEIS);

  // Gestreamt statt am Stueck: dieser Schritt uebernimmt im Wesentlichen eine
  // schon feststehende Vorlage (nur Anrede/Name/Platzhalter werden noch
  // angepasst) - der Mitarbeiter sieht den Text darum schon waehrend des
  // Schreibens statt erst am Schluss auf den kompletten Block zu warten.
  const system = 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Mails zu verfassen.';
  const userText = teile.join('\n\n');
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      try {
        const { tokensInput, tokensOutput } = await rufeClaudeAufStreamend(modell, system, userText, 2500, (chunk) => {
          controller.enqueue(encoder.encode(chunk));
        });
        await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', body.vorlageId, tokensInput, tokensOutput);
      } catch (e) {
        // Ein einmal gestartetes Streaming laesst sich nicht mehr in eine
        // normale Fehler-Antwort mit Statuscode umwandeln - stattdessen einen
        // erkennbaren Marker in den Text schreiben, den die Erweiterung als
        // Fehler statt als Entwurf behandelt.
        controller.enqueue(encoder.encode('\u0000FEHLER:' + String((e as any)?.message || e)));
      } finally {
        controller.close();
      }
    },
  });
  return new Response(stream, { headers: { ...corsHeaders, 'Content-Type': 'text/plain; charset=utf-8' } });
}

// ----------------------------------------------------------------------------
// Modus: auswahl-antwort - Fortsetzung nach Fall 4 (zwei Vorlagen kamen in
// Frage, Mitarbeiter hat eine gewaehlt). Anders als bei rueckfrage-antwort
// gibt es keine vordefinierten Zweige - es wird direkt der Vorlagentext der
// gewaehlten Vorlage verwendet, genau wie beim normalen direkten Entwurf.
// Wird auch fuer Kundenanfragen-Antwort-Vorlagen genutzt (dort per vorlageId
// statt vorlageTitel, da es keine KI-Auswahl gibt, der Mitarbeiter waehlt
// direkt eine konkrete Vorlage aus der Liste), UND fuer die kompakten
// "Weiterleiten"-Buttons je Partnerbetrieb (body.partnerbetriebId) - deren
// Weiterleitungstext liegt direkt auf mailassistent_partnerbetrieb statt in
// einer eigenen Vorlage (1:1 an den Partnerbetrieb gebunden).
// ----------------------------------------------------------------------------
async function modusAuswahlAntwort(body: any, modell: string) {
  const [{ data: schreibstil }, { data: firmendaten }] = await Promise.all([
    sb.from('mailassistent_schreibstil').select('*').limit(1).maybeSingle(),
    sb.from('mailassistent_firmendaten').select('*').limit(1).maybeSingle(),
  ]);

  let titel: string, inhalt: string, logVorlageId: string | null;
  if (body.partnerbetriebId) {
    const { data: partner } = await sb.from('mailassistent_partnerbetrieb').select('*').eq('id', body.partnerbetriebId).maybeSingle();
    if (!partner) return json({ error: 'Partnerbetrieb nicht gefunden.' }, 502);
    titel = partner.name; inhalt = partner.weiterleitung_text || ''; logVorlageId = null;
  } else if (body.eigeneAbsage) {
    const { data: meta } = await sb.from('mailassistent_distanzlogik_meta').select('absage_text').limit(1).maybeSingle();
    titel = 'Absage (zu weit entfernt)'; inhalt = meta?.absage_text || ''; logVorlageId = null;
  } else {
    const vorlagePromise = body.vorlageId
      ? sb.from('mailassistent_vorlage').select('*').eq('id', body.vorlageId).maybeSingle()
      : sb.from('mailassistent_vorlage').select('*').eq('richtung', 'antworten').eq('titel', body.vorlageTitel).maybeSingle();
    const { data: vorlage } = await vorlagePromise;
    if (!vorlage) return json({ error: 'Vorlage "' + (body.vorlageTitel || body.vorlageId) + '" nicht gefunden.' }, 502);
    titel = vorlage.titel; inhalt = vorlage.inhalt; logVorlageId = vorlage.id;
  }
  if (!inhalt.trim()) return json({ error: 'Für "' + titel + '" ist noch kein Text hinterlegt.' }, 502);

  const teile = [];
  if (schreibstil?.immer_antworten && schreibstil.inhalt) teile.push('SCHREIBSTIL:\n' + schreibstil.inhalt);
  if (firmendaten?.immer_antworten) teile.push('FIRMENDATEN:\n' + formatiereFirmendaten(firmendaten));
  teile.push(`VORLAGE - als starke Richtschnur nehmen (Kernaussage/Entscheidung und Aufbau bleiben, das ist nicht verhandelbar), aber natürlich personalisieren: Namen der Person ansprechen, wo sinnvoll kurz auf Details aus der eingehenden Mail eingehen. Nicht stur wortwörtlich abschreiben, aber auch nichts an der eigentlichen Entscheidung/Aussage ändern.
Platzhalter in eckigen Klammern (z.B. [Bauteil], [X Minuten]) werden so behandelt:
- Einen Platzhalter der Form [ZF:...] IMMER exakt unveraendert stehen lassen - der wird danach automatisch ersetzt.
- JEDEN Platzhalter, der das Wort "Datum" enthaelt (z.B. [Datum], [Datum, Uhrzeit]), IMMER exakt unveraendert stehen lassen - der wird separat behandelt.
- Jeden ANDEREN Platzhalter: kannst du aus der eingehenden Mail/dem Kontext einen konkreten, sinnvollen Wert ableiten, ersetze ihn durch diesen Wert in DOPPELTEN eckigen Klammern, z.B. wird aus [Bauteil] -> [[Ablaufventil]]. Bist du dir nicht sicher, lass ihn stattdessen unveraendert in einfachen eckigen Klammern stehen. Erfinde NIE einen Wert, den du nicht wirklich aus dem Kontext hast.
- Text OHNE Klammern in der VORLAGE (z.B. schon konkrete Namen, Adressen, Telefonnummern, E-Mail-Adressen) bleibt IMMER exakt unveraendert stehen - erstelle NIEMALS neue eckige Klammern um bereits konkrete Angaben, auch nicht um sie "generischer" oder "vorlagenhafter" wirken zu lassen.
VORLAGE:\n${inhalt}`);
  if (body.mailInhalt) teile.push('EINGEHENDE MAIL:\n' + body.mailInhalt);
  if (body.anweisung) teile.push('ZUSAETZLICHE ANWEISUNG: ' + body.anweisung);
  teile.push('Schreibe jetzt den fertigen Mailtext. Nur den Mailtext ausgeben, keine Erklärung.' + KG_FORMAT_HINWEIS);

  // Gleiches Streaming-Muster wie rueckfrage-antwort - auch hier ist die
  // Vorlage ja schon feststehend, nur noch leicht anzupassen.
  const system = 'Du hilfst einem Gartenbau-Unternehmen (Knechtgarten), professionelle Mails zu verfassen.';
  const userText = teile.join('\n\n');
  const stream = new ReadableStream({
    async start(controller) {
      const encoder = new TextEncoder();
      try {
        const { tokensInput, tokensOutput } = await rufeClaudeAufStreamend(modell, system, userText, 2500, (chunk) => {
          controller.enqueue(encoder.encode(chunk));
        });
        await protokolliereNutzung(body.mitarbeiterEmail, 'antworten', logVorlageId, tokensInput, tokensOutput);
      } catch (e) {
        controller.enqueue(encoder.encode('\u0000FEHLER:' + String((e as any)?.message || e)));
      } finally {
        controller.close();
      }
    },
  });
  return new Response(stream, { headers: { ...corsHeaders, 'Content-Type': 'text/plain; charset=utf-8' } });
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
  teile.push('Schreibe den überarbeiteten Mailtext. Nur den Mailtext ausgeben, keine Erklärung.' + KG_FORMAT_HINWEIS);

  const { text, tokensInput, tokensOutput } = await rufeClaudeAuf(modell, 'Du überarbeitest einen Mail-Entwurf für Knechtgarten nach einer Anweisung.', teile.join('\n\n'), 2500);
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
  // parent_id gruppiert mehrere Vorlagen unter einem gemeinsamen
  // Dropdown-Button (typ='dropdown' = die Gruppe selbst, ohne eigenen Inhalt).
  // zusatzfenster (falls zugewiesen, ueber die Zuordnungstabelle - ein
  // Zusatzfenster kann mehreren Vorlagen zugewiesen sein und umgekehrt) sagt
  // der Erweiterung, dass vor dem Erstellen erst eine oder mehrere
  // strukturierte Eingabemasken (z.B. Bestell-Tabellen) gezeigt werden
  // muessen statt sofort einzufuegen.
  const { data, error } = await sb.from('mailassistent_vorlage')
    .select(`id,titel,typ,inhalt,betreff,parent_id,
      mailassistent_vorlage_zusatzfenster(
        mailassistent_zusatzfenster(id,typ,titel,platzhalter,erlaubt_eigene_eingabe,zeigt_anzahl,
          mailassistent_zusatzfenster_spalte(id,titel,typ,einheit,platzhalter,breite,reihenfolge,
            mailassistent_zusatzfenster_spalte_option(id,wert,reihenfolge)),
          mailassistent_zusatzfenster_position(id,titel,reihenfolge)))`)
    .eq('richtung', 'verfassen').eq('aktiv', true).order('reihenfolge');
  if (error) return json({ error: 'Vorlagen konnten nicht geladen werden: ' + error.message }, 500);
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
      case 'auswahl-antwort': return await modusAuswahlAntwort(body, modell);
      case 'nachbessern': return await modusNachbessern(body, modell);
      default: return json({ error: 'Unbekannter modus: ' + body.modus }, 400);
    }
  } catch (e) {
    console.error(e);
    return json({ error: String(e?.message || e) }, 500);
  }
});
