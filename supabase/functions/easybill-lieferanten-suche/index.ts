// ============================================================================
// Offertentool 2027 - Easybill-Lieferantensuche (read-only)
//
// Haelt den Easybill-API-Key serverseitig geheim (nie im Browser-Code
// sichtbar). Nutzt denselben /customers-Endpunkt wie die Kundensuche -
// Easybill liefert dort Kunden UND Lieferanten gemischt zurueck, siehe
// Kommentar in easybill-kunden-suche/index.ts. Hier werden bewusst nur die
// Datensaetze mit einer Lieferantennummer ("supplier_number") behalten.
// Schreibt NICHTS nach Easybill zurueck (nur lesender Zugriff).
//
// Aufruf vom Client: sb.functions.invoke('easybill-lieferanten-suche', { body: { q: 'suchtext' } })
// ============================================================================

const EASYBILL_BASE_URL = 'https://api.easybill.de/rest/v1';

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { q } = await req.json().catch(() => ({ q: '' }));
    const suchtext = (q || '').trim();
    if (suchtext.length < 3) {
      return json({ lieferanten: [] });
    }

    const apiKey = Deno.env.get('EASYBILL_API_KEY');
    const email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) {
      return json({ error: 'Easybill ist noch nicht konfiguriert (EASYBILL_API_KEY/EASYBILL_EMAIL fehlen).' }, 500);
    }
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const istNumerisch = /^\d+$/.test(suchtext);
    const felder = ['company_name', 'last_name'];
    if (istNumerisch) felder.push('zip_code');

    const antworten = await Promise.all(
      felder.map((feld) =>
        fetch(`${EASYBILL_BASE_URL}/customers?${feld}=${encodeURIComponent(suchtext)}&limit=15`, { headers: { Authorization: auth } })
          .then(async (res) => (res.ok ? res.json() : null))
          .catch(() => null)
      )
    );

    const alleTreffer = antworten
      .filter((r) => r !== null)
      .flatMap((r: any) => (Array.isArray(r) ? r : (r.items || r.data || [])));

    const gesehen = new Set<number>();
    const lieferanten = alleTreffer
      .filter((k: any) => {
        if (gesehen.has(k.id)) return false;
        gesehen.add(k.id);
        // Nur echte Lieferanten (haben eine Lieferantennummer) - keine
        // reinen Kunden-Datensaetze (haben nur eine Kundennummer).
        return !!k.supplier_number;
      })
      .map((k: any) => ({
        easybill_id: k.id,
        name: k.company_name || [k.first_name, k.last_name].filter(Boolean).join(' '),
        firma: k.company_name || null,
        vorname: k.first_name || null,
        nachname: k.last_name || null,
        lieferantennummer: k.supplier_number || null,
        plz: k.zip_code || null,
        ort: k.city || null,
        strasse: k.street || null,
        land: k.country || null,
        email: (k.emails && k.emails[0]) || null,
        emails: k.emails || [],
        telefon1: k.phone_1 || null,
        telefon2: k.phone_2 || null,
        fax: k.fax || null,
        mobil: k.mobile || null,
      }));

    return json({ lieferanten });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
