// ============================================================================
// Knechtgarten - neuen Kunden in Easybill anlegen (nur auf Knopfdruck)
//
// Ausnahme vom Grundsatz «Easybill nur lesen» (Entscheid 2026-11-05): wer im
// Pendenzen-Tool einen Kunden nicht findet, legt ihn mit einem Klick direkt in
// Easybill an. Es wird nichts automatisch synchronisiert - nur diese eine,
// bewusste Aktion. Die Antwort hat dasselbe Format wie easybill-kunden-suche,
// der Browser übernimmt den Kunden danach mit easybill_id in Kontakte.
//
// Aufruf: sb.functions.invoke('easybill-kunde-anlegen', { body: { vorname, nachname,
//   firma, anrede, strasse, plz, ort, telefon, mobil, email } })
// ============================================================================

const EASYBILL_BASE_URL = 'https://api.easybill.de/rest/v1';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

// Easybill-Anrede: 0 leer, 1 Herr, 2 Frau, 3 Firma, 4 Herr und Frau, 5 Eheleute, 6 Familie
const ANREDE: Record<string, number> = { herr: 1, frau: 2, firma: 3, 'herr und frau': 4, familie: 6 };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const b = await req.json().catch(() => ({}));
    const t = (x: unknown) => (typeof x === 'string' ? x.trim() : '');
    const vorname = t(b.vorname), nachname = t(b.nachname), firma = t(b.firma);
    if (!nachname && !firma) return json({ error: 'Bitte einen Nachnamen oder eine Firma angeben.' }, 400);

    const apiKey = Deno.env.get('EASYBILL_API_KEY'), email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist noch nicht konfiguriert (EASYBILL_API_KEY/EASYBILL_EMAIL fehlen).' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const mail = t(b.email);
    const body: Record<string, unknown> = {
      first_name: vorname || null,
      last_name: nachname || null,
      company_name: firma || null,
      salutation: ANREDE[t(b.anrede).toLowerCase()] ?? 0,
      street: t(b.strasse) || null,
      zip_code: t(b.plz) || null,
      city: t(b.ort) || null,
      country: 'CH',
      phone_1: t(b.telefon) || null,
      mobile: t(b.mobil) || null,
      emails: mail ? [mail] : [],
    };
    const res = await fetch(`${EASYBILL_BASE_URL}/customers`, {
      method: 'POST', headers: { Authorization: auth, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    const k: any = await res.json().catch(() => null);
    if (!res.ok || !k?.id) return json({ error: `Easybill hat den Kunden nicht angelegt (${res.status}): ${k?.message || JSON.stringify(k)}` }, 502);

    return json({
      kunde: {
        easybill_id: k.id,
        name: k.company_name || [k.first_name, k.last_name].filter(Boolean).join(' '),
        firma: k.company_name || null,
        vorname: k.first_name || null,
        nachname: k.last_name || null,
        kundennummer: k.number || null,
        plz: k.zip_code || null,
        ort: k.city || null,
        strasse: k.street || null,
        land: k.country || null,
        emails: k.emails || [],
        telefon1: k.phone_1 || null,
        telefon2: k.phone_2 || null,
        fax: k.fax || null,
        mobil: k.mobile || null,
      },
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
