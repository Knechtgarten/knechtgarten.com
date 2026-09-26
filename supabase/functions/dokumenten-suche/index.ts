// ============================================================================
// Dokumenten-Suche - Phase 2 (noch OHNE KI-Ebene, siehe Fahrplan Session
// 2026-09-27): nimmt einen Suchbegriff + ein Google-Access-Token entgegen,
// fragt direkt Drive und Gmail an und gibt die rohen Treffer zurueck. Die
// KI-Ebene (mehrere gezielte Anfragen ableiten, Treffer inhaltlich bewerten,
// "Hohe/Moegliche Uebereinstimmung") kommt erst in Phase 3 dazu, wenn diese
// Grundverbindung nachweislich funktioniert.
//
// Wird von der Browser-Erweiterung aufgerufen. Das Google-Access-Token holt
// die Erweiterung selbst per chrome.identity.getAuthToken() vom Google-
// Konto der/des Mitarbeitenden (Scopes: drive.readonly, gmail.readonly) -
// diese Function bekommt es nur durchgereicht und ruft Google direkt per
// fetch() an (kein SDK, gleiches Muster wie die anderen Functions in diesem
// Repo, z.B. distance-matrix).
//
// WICHTIG, noch offen: Google-Cloud-Projekt + OAuth-Client fuer die
// Erweiterung existieren noch nicht (siehe Projekt-Notiz
// browser-erweiterung-dokumentensuche) - diese Function ist erst testbar,
// sobald das steht.
//
// PEAX ist bewusst NICHT Teil dieser Function (kein API-Zugang, siehe
// Projekt-Notiz) - die Erweiterung oeffnet PEAX' eigene Suche stattdessen
// direkt in einem neuen Tab, ohne ueber das Backend zu gehen.
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

interface Ergebnis {
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

async function sucheDrive(query: string, token: string, zeitraumVon?: string): Promise<Ergebnis[]> {
  const bedingungen = [`fullText contains '${escapeDriveQuery(query)}'`, 'trashed = false'];
  if (zeitraumVon) bedingungen.push(`modifiedTime >= '${zeitraumVon}'`);
  const params = new URLSearchParams({
    q: bedingungen.join(' and '),
    fields: 'files(id,name,mimeType,modifiedTime,webViewLink)',
    pageSize: '15',
  });
  const res = await fetch(`https://www.googleapis.com/drive/v3/files?${params}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) {
    throw new Error(`Drive-Suche fehlgeschlagen (${res.status}): ${await res.text()}`);
  }
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

async function sucheGmail(query: string, token: string, zeitraumVon?: string, papierkorbSpam = false): Promise<Ergebnis[]> {
  let gmailQuery = query;
  if (zeitraumVon) gmailQuery += ` after:${zeitraumVon.slice(0, 10).replace(/-/g, '/')}`;
  if (papierkorbSpam) gmailQuery += ' in:anywhere';
  const listParams = new URLSearchParams({ q: gmailQuery, maxResults: '15' });
  const listRes = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/messages?${listParams}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!listRes.ok) {
    throw new Error(`Gmail-Suche fehlgeschlagen (${listRes.status}): ${await listRes.text()}`);
  }
  const liste = await listRes.json();
  const ids: string[] = (liste.messages || []).map((m: any) => m.id);

  // Details (Betreff/Datum/Absender) einzeln nachladen - Gmail liefert das
  // nicht schon in der Liste mit. Auf die ersten 15 Treffer begrenzt, damit
  // die Function nicht zu lange laeuft.
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
  return details.filter((d): d is Ergebnis => d !== null);
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

  const { query, mitarbeiterEmail, googleAccessToken, quellen, zeitraumVon, papierkorbSpam } = body ?? {};
  if (!query || typeof query !== 'string') return json({ error: 'query fehlt.' }, 400);
  if (!mitarbeiterEmail || typeof mitarbeiterEmail !== 'string') return json({ error: 'mitarbeiterEmail fehlt.' }, 400);
  if (!googleAccessToken || typeof googleAccessToken !== 'string') return json({ error: 'googleAccessToken fehlt.' }, 400);

  const gewuenschteQuellen: string[] = Array.isArray(quellen) && quellen.length ? quellen : ['drive', 'gmail'];

  const ergebnisse: Ergebnis[] = [];
  const fehler: string[] = [];

  if (gewuenschteQuellen.includes('drive')) {
    try {
      ergebnisse.push(...await sucheDrive(query, googleAccessToken, zeitraumVon));
    } catch (e) {
      fehler.push(String(e instanceof Error ? e.message : e));
    }
  }
  if (gewuenschteQuellen.includes('gmail')) {
    try {
      ergebnisse.push(...await sucheGmail(query, googleAccessToken, zeitraumVon, !!papierkorbSpam));
    } catch (e) {
      fehler.push(String(e instanceof Error ? e.message : e));
    }
  }

  // Nutzung protokollieren (fuer die "Nutzung"-Ansicht im Verwaltungstool) -
  // Service-Role-Client wie bei mail-assistent-draft, da die Erweiterung kein
  // eigenes Supabase-Login hat (nur Google-Konto).
  try {
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    await sb.from('dokumentensuche_nutzung_log').insert({
      mitarbeiter_email: mitarbeiterEmail,
      suchbegriff: query,
      quellen: gewuenschteQuellen,
    });
  } catch (e) {
    // Logging-Fehler sollen die eigentliche Suche nicht scheitern lassen.
    console.error('Nutzungs-Log fehlgeschlagen:', e);
  }

  return json({ ergebnisse, fehler: fehler.length ? fehler : undefined });
});
