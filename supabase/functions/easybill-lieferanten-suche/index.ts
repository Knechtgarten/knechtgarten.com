// ============================================================================
// Offertentool 2027 - Easybill-Lieferantenliste (read-only)
//
// Haelt den Easybill-API-Key serverseitig geheim (nie im Browser-Code
// sichtbar). Easybill kennt keinen "type"-Filter bei GET /customers und die
// Feld-Filter (company_name, last_name, ...) matchen offenbar nur exakt statt
// unscharf - eine Suche nach nur "Koi" statt "Koi-Breeder" fand darum
// vorher nichts. Deshalb wird hier stattdessen die KOMPLETTE Kontaktliste
// einmal geholt (paginiert), auf Datensaetze mit einer Lieferantennummer
// ("supplier_number") eingegrenzt und komplett zurueckgegeben - die eigentliche
// (unscharfe, mehrfeldrige) Suche passiert im Browser ueber die schon
// geladene Liste. Schreibt NICHTS nach Easybill zurueck.
//
// Aufruf vom Client: sb.functions.invoke('easybill-lieferanten-suche')
// ============================================================================

const EASYBILL_BASE_URL = 'https://api.easybill.de/rest/v1';
const SEITENGROESSE = 200;
const MAX_SEITEN = 10; // Sicherheitsgrenze (max. 2000 Kontakte) gegen Endlos-Paginierung.

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
    const apiKey = Deno.env.get('EASYBILL_API_KEY');
    const email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) {
      return json({ error: 'Easybill ist noch nicht konfiguriert (EASYBILL_API_KEY/EASYBILL_EMAIL fehlen).' }, 500);
    }
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const alleKontakte: any[] = [];
    for (let seite = 1; seite <= MAX_SEITEN; seite++) {
      const res = await fetch(`${EASYBILL_BASE_URL}/customers?page=${seite}&limit=${SEITENGROESSE}`, { headers: { Authorization: auth } });
      if (!res.ok) {
        if (seite === 1) return json({ error: `Easybill-Abfrage fehlgeschlagen (Status ${res.status}).` }, 400);
        break;
      }
      const daten = await res.json();
      const items = Array.isArray(daten) ? daten : (daten.items || daten.data || []);
      alleKontakte.push(...items);
      if (items.length < SEITENGROESSE) break; // letzte Seite erreicht
    }

    const lieferanten = alleKontakte
      .filter((k: any) => !!k.supplier_number)
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

    // TEMPORAERE DIAGNOSE: unser Feldname "supplier_number" liefert bei
    // bekannten Lieferanten wie "Koi-Breeder" nichts, obwohl die
    // Lieferantennummer in Easybill sichtbar gesetzt ist - vermutlich
    // stimmt der Feldname in der echten API-Antwort nicht. Diese Rohdaten
    // zeigen alle vorhandenen Feldnamen, damit wir den richtigen finden.
    // Danach wieder entfernen.
    const diagnoseTreffer = alleKontakte.filter((k: any) =>
      String(k.company_name || '').toLowerCase().includes('koi') ||
      String(k.last_name || '').toLowerCase().includes('koi')
    );

    return json({ lieferanten, anzahl_kontakte_gesamt: alleKontakte.length, diagnose_koi: diagnoseTreffer });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
