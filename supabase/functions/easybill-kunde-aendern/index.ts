// ============================================================================
// Knechtgarten - Kundenänderung nach Easybill schreiben (nur auf Knopfdruck)
//
// Ausnahme vom Grundsatz «Easybill nur lesen» (Entscheid 2026-11-19): ändert
// jemand in Kontakte oder im Offertentool Name, Adresse, Telefon oder Mail
// eines Easybill-Kunden, geht die Änderung gleich nach Easybill – sonst würde
// der Nachtabgleich sie wieder überschreiben.
// Zusätzlich: Easybill-Angebote der angekreuzten Offerten, die in Easybill noch
// ein ENTWURF sind, bekommen die neue Adresse (refresh_customer_data).
// Abgeschlossene Easybill-Dokumente werden nie geändert.
//
// Aufruf (nach rpc kunde_adresse_aendern, liest den Kunden aus der Datenbank):
//   sb.functions.invoke('easybill-kunde-aendern', { body: { kunde_id, dokumente: [easybill_document_id, …] } })
// Antwort: { ok, dokumente: [{ id, ergebnis: 'aktualisiert' | 'abgeschlossen' | 'fehler', text? }] }
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const EB = 'https://api.easybill.de/rest/v1';
const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

// Easybill-Anrede: 0 leer, 1 Herr, 2 Frau, 3 Firma, 4 Herr und Frau, 5 Eheleute, 6 Familie
const ANREDE: Record<string, number> = { herr: 1, frau: 2, firma: 3, 'herr und frau': 4, familie: 6 };
const LAND: Record<string, string> = { schweiz: 'CH', deutschland: 'DE', 'österreich': 'AT', liechtenstein: 'LI', frankreich: 'FR', italien: 'IT' };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    // nur angemeldete Personen, die Kunden bearbeiten dürfen
    const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } } });
    const { data: { user } } = await nutzer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const { data: darf } = await nutzer.rpc('kunde_darf_bearbeiten');
    if (!darf) return json({ error: 'Keine Berechtigung, Kunden zu bearbeiten.' }, 403);

    const b = await req.json().catch(() => ({}));
    const { data: k } = await db.from('kunde').select('*').eq('id', b.kunde_id).maybeSingle();
    if (!k) return json({ error: 'Kunde nicht gefunden.' }, 404);
    if (!k.easybill_id) return json({ ok: true, nichtVerknuepft: true, dokumente: [] });

    const apiKey = Deno.env.get('EASYBILL_API_KEY'), email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist nicht konfiguriert.' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);
    const eb = async (pfad: string, method = 'GET', body?: unknown) => {
      for (let versuch = 0; versuch < 3; versuch++) {
        const r = await fetch(EB + pfad, { method, headers: { Authorization: auth, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
        if (r.status === 429) { await new Promise((ok) => setTimeout(ok, 3000)); continue; }
        const d: any = await r.json().catch(() => null);
        return { ok: r.ok, status: r.status, d };
      }
      return { ok: false, status: 429, d: { message: 'Zu viele Anfragen an Easybill.' } };
    };

    // 1) Kunde: aktuellen Datensatz holen und nur unsere Felder ersetzen (PUT schickt das ganze Objekt)
    const alt = await eb(`/customers/${k.easybill_id}`);
    if (!alt.ok) return json({ error: `Easybill-Kunde nicht gefunden (${alt.status}).` }, 502);
    const kd = k.kontaktdaten || {};
    const mails = (Array.isArray(kd.emails) ? kd.emails : []).filter(Boolean).slice(0, 3);
    const neu: Record<string, unknown> = {
      ...alt.d,
      first_name: k.vorname || null,
      last_name: k.nachname || null,
      company_name: k.firma || null,
      street: k.strasse || null,
      zip_code: k.plz || null,
      city: k.ort || null,
      country: LAND[String(k.land || '').trim().toLowerCase()] || (String(k.land || '').length === 2 ? k.land : alt.d.country || 'CH'),
      phone_1: kd.telefon1 || null,
      phone_2: kd.telefon2 || null,
      mobile: kd.mobil || null,
      fax: kd.fax || null,
      emails: mails,
    };
    if (k.anrede != null) neu.salutation = ANREDE[String(k.anrede).toLowerCase()] ?? 0;
    if (k.zusatz1 !== undefined) neu.suffix_1 = k.zusatz1 || null;
    if (k.zusatz2 !== undefined) neu.suffix_2 = k.zusatz2 || null;
    for (const f of ['id', 'created_at', 'updated_at', 'display_name', 'payment_provider_mandate_status']) delete neu[f];
    const put = await eb(`/customers/${k.easybill_id}`, 'PUT', neu);
    if (!put.ok) return json({ error: `Easybill hat die Änderung nicht übernommen (${put.status}): ${put.d?.message || JSON.stringify(put.d)}` }, 502);

    // 2) Angebote der angekreuzten Offerten: nur Entwürfe neu mit den Kundendaten füllen
    const dokumente: { id: number; ergebnis: string; text?: string }[] = [];
    for (const id of (Array.isArray(b.dokumente) ? b.dokumente : []).filter(Boolean).slice(0, 50)) {
      const g = await eb(`/documents/${id}`);
      if (!g.ok) { dokumente.push({ id, ergebnis: 'fehler', text: `nicht gefunden (${g.status})` }); continue; }
      if (!g.d.is_draft) { dokumente.push({ id, ergebnis: 'abgeschlossen' }); continue; }
      const p = await eb(`/documents/${id}?refresh_customer_data=1`, 'PUT', { customer_id: k.easybill_id });
      dokumente.push(p.ok ? { id, ergebnis: 'aktualisiert', text: [p.d?.address?.street, p.d?.address?.zip_code, p.d?.address?.city].filter(Boolean).join(' ') }
                          : { id, ergebnis: 'fehler', text: `${p.status} ${p.d?.message || ''}`.trim() });
    }
    return json({ ok: true, dokumente });
  } catch (e) {
    return json({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
