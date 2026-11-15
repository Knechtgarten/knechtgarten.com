// ============================================================================
// easybill-angebote-sync – liest die Positionen aller Easybill-Angebote in die
// Tabelle easybill_angebot_zeile (Wissensquelle für die KI-Offerte).
// - body {voll: true}: alles neu einlesen (seitenweise, setzt bei Zeitablauf fort)
// - sonst: nur Angebote, die seit dem letzten Lauf in Easybill geändert wurden
// Nur lesen in Easybill. Läuft pro Aufruf höchstens ~100 s, danach {fertig:false}.
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const EASYBILL = 'https://api.easybill.de/rest/v1';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}
const ENT: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', auml: 'ä', ouml: 'ö', uuml: 'ü', Auml: 'Ä', Ouml: 'Ö', Uuml: 'Ü', szlig: 'ss', eacute: 'é', egrave: 'è', agrave: 'à', ndash: '–', mdash: '—', sup2: '²', sup3: '³', deg: '°', Oslash: 'Ø', oslash: 'ø' };
function sauber(s: string): string {
  return String(s || '')
    .replace(/<br\s*\/?>/gi, ' / ').replace(/<\/p>/gi, ' / ').replace(/<[^>]+>/g, '')
    .replace(/&(#\d+|[a-zA-Z]+);/g, (m, e) => e[0] === '#' ? String.fromCharCode(Number(e.slice(1))) : (ENT[e] ?? m))
    .replace(/\s*\n\s*/g, ' / ').replace(/\s+/g, ' ').replace(/( \/ )+/g, ' / ').replace(/^ \/ | \/ $/g, '').trim();
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  const start = Date.now();
  try {
    const body = await req.json().catch(() => ({}));
    const apiKey = Deno.env.get('EASYBILL_API_KEY'), email = Deno.env.get('EASYBILL_EMAIL');
    if (!apiKey || !email) return json({ error: 'Easybill ist noch nicht konfiguriert.' }, 500);
    const auth = 'Basic ' + btoa(`${email}:${apiKey}`);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: st } = await sb.from('easybill_sync_status').select('wert').eq('schluessel', 'angebote').maybeSingle();
    const status: any = st?.wert || {};
    const voll = !!body?.voll || !status.letzter_lauf || status.modus === 'voll';
    const heute = new Date().toISOString().slice(0, 10);
    // Voll: bei der gespeicherten Seite weiterfahren. Nachführen: geändert seit letztem Lauf (1 Tag Puffer).
    let seite = voll ? (body?.voll ? 1 : (status.seite || 1)) : 1;
    const seit = status.letzter_lauf ? new Date(new Date(status.letzter_lauf).getTime() - 86400000).toISOString().slice(0, 10) : null;
    const filter = voll ? '' : `&edited_at=${seit},${heute}`;
    let dokumente = 0, zeilen = 0, seiten = 0, fertig = false;

    while (Date.now() - start < 100000) {
      const res = await fetch(`${EASYBILL}/documents?type=OFFER&limit=100&page=${seite}${filter}`, { headers: { Authorization: auth } });
      if (res.status === 429) { await new Promise((r) => setTimeout(r, 3000)); continue; }
      if (!res.ok) return json({ error: `Easybill (${res.status})`, seite }, 502);
      const r = await res.json();
      seiten = r.pages || 1;
      const docs = r.items || [];
      for (const d of docs) {
        const kunde = sauber([d.address?.company_name, [d.address?.first_name, d.address?.last_name].filter(Boolean).join(' ')].filter(Boolean).join(', '));
        const rows = (d.items || [])
          .filter((i: any) => (i.type === 'POSITION' || i.type === 'POSITION_NOCALC') && sauber(i.description))
          .map((i: any, n: number) => ({
            document_id: d.id, document_number: d.number || null, document_date: d.document_date || null, titel: sauber(d.title || '') || null, kunde: kunde || null,
            position: i.position ?? n + 1, typ: i.type, bezeichnung: sauber(i.description).slice(0, 2000), menge: i.quantity ?? null, einheit: i.unit || null,
            preis: i.single_price_net != null ? Number(i.single_price_net) / 100 : null,
            rabatt: i.discount != null ? (i.discount_type === 'PERCENT' ? Number(i.discount) : Number(i.discount) / 100) : null,
            rabatt_typ: i.discount_type || null, mwst: i.vat_percent ?? null,
          }));
        await sb.from('easybill_angebot_zeile').delete().eq('document_id', d.id);
        if (d.cancel_id) continue; // stornierte Angebote nicht als Quelle
        if (rows.length) {
          const { error } = await sb.from('easybill_angebot_zeile').insert(rows);
          if (error) return json({ error: 'Speichern: ' + error.message, seite }, 500);
        }
        dokumente++; zeilen += rows.length;
      }
      if (seite >= seiten || !docs.length) { fertig = true; break; }
      seite++;
    }

    const neu = fertig ? { letzter_lauf: new Date().toISOString(), modus: 'nachfuehren', seite: 1 } : { ...status, modus: voll ? 'voll' : 'nachfuehren', seite, letzter_lauf: status.letzter_lauf || null };
    await sb.from('easybill_sync_status').upsert({ schluessel: 'angebote', wert: neu, geaendert_am: new Date().toISOString() });
    return json({ fertig, voll, seite, seiten, dokumente, zeilen });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
