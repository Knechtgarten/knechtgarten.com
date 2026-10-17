// ============================================================================
// Pflege-Tool - Easybill-Dokumente eines Kunden lesen (nur lesen, nie schreiben)
//
// Haelt den Easybill-API-Key serverseitig geheim. Zwei Aktionen:
//   { aktion: 'liste', customer_id, typ: 'ORDER' | 'OFFER' | 'ALLE' }
//       -> { dokumente: [{ id, nummer, typ, datum, titel, betrag, ausgefuehrt_von, storniert }] }
//          neueste zuerst, Entwuerfe ausgeschlossen. «Ausgefuehrt von» = der in
//          Easybill zugeordnete Benutzer (login_id, «Verknuepft mit»).
//   { aktion: 'pdf', document_id }
//       -> das PDF (application/pdf), z.B. zum Anzeigen oder um beim Verknuepfen
//          eines Angebots eine Kopie im Pflege-Tool zu speichern.
//
// Nur fuer freigeschaltete Benutzer (Rolle gesetzt, aktiv) - serverseitig geprueft.
// Aufruf: sb.functions.invoke('pflege-easybill', { body: { aktion: 'liste', customer_id: 123, typ: 'ORDER' } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

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

const TYP_LABEL: Record<string, string> = {
  ORDER: 'Auftrag', OFFER: 'Angebot', INVOICE: 'Rechnung', CREDIT: 'Gutschrift', DELIVERY: 'Lieferschein',
  REMINDER: 'Zahlungserinnerung', DUNNING: 'Mahnung', STORNO: 'Storno', LETTER: 'Brief', PDF: 'PDF',
  PROFORMA_INVOICE: 'Proforma-Rechnung', CHARGE: 'Auftrag (Charge)', CHARGE_CONFIRM: 'Auftragsbestätigung',
};

// Easybill-Benutzer (fuer «Ausgefuehrt von») - pro Function-Instanz zwischengespeichert
let loginCache: { zeit: number; namen: Record<number, string> } | null = null;
async function loginNamen(auth: string): Promise<Record<number, string>> {
  if (loginCache && Date.now() - loginCache.zeit < 30 * 60 * 1000) return loginCache.namen;
  const res = await fetch(`${EASYBILL_BASE_URL}/logins?limit=1000`, { headers: { Authorization: auth } });
  const namen: Record<number, string> = {};
  if (res.ok) {
    const d = await res.json();
    for (const l of d.items || []) namen[l.id] = [l.first_name, l.last_name].filter((x: string) => x && x !== '.').join(' ') || l.display_name || '';
  }
  loginCache = { zeit: Date.now(), namen };
  return namen;
}

function kurzTitel(d: any): string {
  if (d.title) return d.title;
  const erste = (d.items || []).find((i: any) => i.type === 'POSITION' || i.type === 'TEXT');
  return (erste?.description || '').split('\n')[0].slice(0, 120);
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    // Aufrufer pruefen: angemeldet + freigeschaltet + aktiv
    const sbAlsAufrufer = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') || '' } },
    });
    const { data: { user } } = await sbAlsAufrufer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const { data: b } = await sbAlsAufrufer.from('benutzer').select('rolle,aktiv').eq('id', user.id).maybeSingle();
    if (!b?.rolle || !b.aktiv) return json({ error: 'Kein Zugriff.' }, 403);

    const apiKey = Deno.env.get('EASYBILL_API_KEY');
    const email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist nicht konfiguriert.' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const body = await req.json().catch(() => ({}));

    if (body.aktion === 'liste') {
      const customerId = Number(body.customer_id);
      if (!customerId) return json({ error: 'customer_id fehlt.' }, 400);
      const typ = ['ORDER', 'OFFER'].includes(body.typ) ? `&type=${body.typ}` : '';
      // Easybill sortiert nicht nach Datum -> alle Dokumente des Kunden holen (max. 1000) und selbst sortieren
      const [res, namen] = await Promise.all([
        fetch(`${EASYBILL_BASE_URL}/documents?customer_id=${customerId}${typ}&is_draft=0&limit=1000`, { headers: { Authorization: auth } }),
        loginNamen(auth),
      ]);
      if (!res.ok) return json({ error: `Easybill antwortet mit ${res.status}.` }, 502);
      const d = await res.json();
      const dokumente = (d.items || [])
        .map((x: any) => ({
          id: x.id,
          nummer: x.number || '',
          typ: x.type,
          typ_label: TYP_LABEL[x.type] || x.type,
          datum: x.document_date,
          titel: kurzTitel(x),
          betrag: typeof x.amount === 'number' ? x.amount / 100 : null,
          ausgefuehrt_von: namen[x.login_id] || '',
          storniert: !!x.cancel_id,
        }))
        .sort((a: any, b: any) => String(b.datum).localeCompare(String(a.datum)) || b.id - a.id);
      return json({ dokumente });
    }

    if (body.aktion === 'pdf') {
      const id = Number(body.document_id);
      if (!id) return json({ error: 'document_id fehlt.' }, 400);
      const res = await fetch(`${EASYBILL_BASE_URL}/documents/${id}/pdf`, { headers: { Authorization: auth } });
      if (!res.ok) return json({ error: `PDF nicht verfügbar (Easybill ${res.status}).` }, 502);
      return new Response(res.body, { headers: { ...corsHeaders, 'Content-Type': 'application/pdf' } });
    }

    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
