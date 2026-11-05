// ============================================================================
// Knechtgarten - Easybill-Offerten eines Kunden (nur lesen)
//
// Für das Vorrat-Fenster im Pendenzen-Tool: alle Offerten (Typ OFFER) eines
// Easybill-Kunden der letzten Jahre, mit den Vorarbeiter-Stunden aus den
// Positionen (Einheit h/Std, Text mit «Vorarbeiter» oder «Polier»). So lassen
// sich auch Offerten einplanen, die direkt in Easybill geschrieben wurden.
//
// Aufruf: sb.functions.invoke('easybill-offerten-kunde', { body: { easybill_id, jahre } })
// ============================================================================

const EASYBILL_BASE_URL = 'https://api.easybill.de/rest/v1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { easybill_id, jahre } = await req.json().catch(() => ({}));
    if (!easybill_id) return json({ offerten: [] });
    const apiKey = Deno.env.get('EASYBILL_API_KEY'), email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist noch nicht konfiguriert.' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);

    const bis = new Date(), von = new Date(); von.setFullYear(von.getFullYear() - (Number(jahre) || 3));
    const d = (x: Date) => x.toISOString().slice(0, 10);
    const alle: any[] = [];
    for (let page = 1; page <= 5; page++) {
      const res = await fetch(`${EASYBILL_BASE_URL}/documents?type=OFFER&customer_id=${encodeURIComponent(String(easybill_id))}&document_date=${d(von)},${d(bis)}&limit=100&page=${page}`, { headers: { Authorization: auth } });
      if (!res.ok) return json({ error: `Easybill (${res.status})` }, 502);
      const r = await res.json();
      alle.push(...(r.items || []));
      if (!r.pages || page >= r.pages) break;
    }
    const istStd = (u: string | null) => /^(h|std\.?|stunden?)$/i.test((u || '').trim());
    const offerten = alle.filter((o) => !o.cancel_id).map((o) => {
      const pos = (o.items || []).filter((i: any) => i.type === 'POSITION' && istStd(i.unit));
      const vorarb = pos.filter((i: any) => /vorarbeiter|polier/i.test(i.description || '')).reduce((s: number, i: any) => s + (Number(i.quantity) || 0), 0);
      const alleStd = pos.reduce((s: number, i: any) => s + (Number(i.quantity) || 0), 0);
      return {
        id: o.id, nummer: o.number || null, titel: o.title || null, datum: o.document_date || null,
        betrag_netto: o.amount_net != null ? o.amount_net / 100 : null, entwurf: !!o.is_draft,
        vorarbeiter_std: vorarb, std_total: alleStd,
      };
    }).sort((a, b) => String(b.datum).localeCompare(String(a.datum)));
    return json({ offerten });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
