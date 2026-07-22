// ============================================================================
// Offertentool 2027 - Easybill-Kundensuche (read-only)
//
// Haelt den Easybill-API-Key serverseitig geheim (nie im Browser-Code
// sichtbar). Sucht bei Easybill nach Firmenname UND Nachname, da Easybill
// kein generisches "name"-Filterfeld kennt. Schreibt NICHTS nach Easybill
// zurueck - siehe Architektur-Entscheid (nur lesender Zugriff).
//
// Aufruf vom Client: sb.functions.invoke('easybill-kunden-suche', { body: { q: 'suchtext' } })
// Durch Supabase automatisch hinter der normalen Auth (Anon/Session-Key)
// abgesichert - nicht oeffentlich ohne gueltigen Supabase-Schluessel aufrufbar.
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
      return json({ kunden: [] });
    }

    const apiKey = Deno.env.get('EASYBILL_API_KEY');
    const email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) {
      return json({ error: 'Easybill ist noch nicht konfiguriert (EASYBILL_API_KEY/EASYBILL_EMAIL fehlen).' }, 500);
    }
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    // Easybill kennt kein generisches "name"-Feld - deshalb parallel nach
    // Firmenname UND Nachname suchen und die Treffer zusammenfuehren.
    // Ein "type"-Filterparameter existiert bei GET /customers NICHT (nur bei
    // POST) - Easybill liefert hier Kunden UND Lieferanten gemischt zurueck.
    // Unterscheidung erfolgt daher weiter unten ueber das Feld "number"
    // (echte Kundennummer) vs. "supplier_number" (Lieferant).
    const [firmaRes, nameRes] = await Promise.all([
      fetch(`${EASYBILL_BASE_URL}/customers?company_name=${encodeURIComponent(suchtext)}&limit=15`, { headers: { Authorization: auth } }),
      fetch(`${EASYBILL_BASE_URL}/customers?last_name=${encodeURIComponent(suchtext)}&limit=15`, { headers: { Authorization: auth } }),
    ]);

    if (!firmaRes.ok || !nameRes.ok) {
      const status = !firmaRes.ok ? firmaRes.status : nameRes.status;
      return json({ error: `Easybill-Anfrage fehlgeschlagen (HTTP ${status}).` }, 502);
    }

    const firmaJson = await firmaRes.json();
    const nameJson = await nameRes.json();
    // Easybill liefert {page, pages, limit, total, items: [...]}.
    const firmaListe = Array.isArray(firmaJson) ? firmaJson : (firmaJson.items || firmaJson.data || []);
    const nameListe = Array.isArray(nameJson) ? nameJson : (nameJson.items || nameJson.data || []);

    const gesehen = new Set<number>();
    const kunden = [...firmaListe, ...nameListe]
      .filter((k: any) => {
        if (gesehen.has(k.id)) return false;
        gesehen.add(k.id);
        // Nur echte Kunden (haben eine Kundennummer) - keine reinen
        // Lieferanten-Datensaetze (haben nur eine supplier_number, teils mit
        // Zugangsdaten zu Lieferanten-Portalen im Notizfeld, das hier ohnehin
        // nie mitgegeben wird - siehe Feld-Whitelist unten).
        return !!k.number;
      })
      .map((k: any) => ({
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
        email: (k.emails && k.emails[0]) || null,
        emails: k.emails || [],
        telefon1: k.phone_1 || null,
        telefon2: k.phone_2 || null,
        fax: k.fax || null,
        mobil: k.mobile || null,
      }));

    return json({ kunden });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
