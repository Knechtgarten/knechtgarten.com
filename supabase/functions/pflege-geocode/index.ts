// ============================================================================
// Pflege-Tool: Adressen in Koordinaten umrechnen (Google Geocoding, serverseitig)
//
// Rechnet fuer Pflegekunden (Hauptadresse) und Objekte die Koordinaten aus, bei
// denen noch keine berechnet sind oder sich die Adresse geaendert hat
// (geo_adresse <> aktuelle Adresse). Pro Aufruf hoechstens MAX Adressen; der
// Client ruft so lange auf, bis «offen» 0 ist.
// Schluessel: Secret GOOGLE_MAPS_API_KEY (derselbe wie fuer distance-matrix).
//
// Aufruf: sb.functions.invoke('pflege-geocode', { body: {} })
//   -> { erledigt, offen, nicht_gefunden: [adresse, ...] }
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

const MAX = 40;
const adresse = (a: { strasse?: string | null; plz?: string | null; ort?: string | null }) =>
  [a.strasse, [a.plz, a.ort].filter(Boolean).join(' ')].filter((x) => x && String(x).trim()).join(', ').trim();

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') || '' } },
    });
    const { data: { user } } = await sb.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const { data: b } = await sb.from('benutzer').select('rolle,aktiv').eq('id', user.id).maybeSingle();
    if (!b?.rolle || !b.aktiv) return json({ error: 'Kein Zugriff.' }, 403);

    const key = Deno.env.get('GOOGLE_MAPS_API_KEY');
    if (!key) return json({ error: 'GOOGLE_MAPS_API_KEY ist auf dem Server nicht konfiguriert.' }, 500);
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const [{ data: kunden, error: e1 }, { data: objekte, error: e2 }] = await Promise.all([
      admin.from('pflege_kunde').select('kunde_id, geo_adresse, kunde(strasse, plz, ort)'),
      admin.from('pflege_objekt').select('id, strasse, plz, ort, geo_adresse'),
    ]);
    if (e1 || e2) return json({ error: (e1 || e2)!.message }, 500);

    type Auftrag = { tabelle: 'pflege_kunde' | 'pflege_objekt'; spalte: string; id: string; adr: string };
    const offen: Auftrag[] = [];
    for (const k of kunden || []) {
      // deno-lint-ignore no-explicit-any
      const adr = adresse((k as any).kunde || {});
      if (adr && adr !== k.geo_adresse) offen.push({ tabelle: 'pflege_kunde', spalte: 'kunde_id', id: k.kunde_id, adr });
    }
    for (const o of objekte || []) {
      const adr = adresse(o);
      if (adr && adr !== o.geo_adresse) offen.push({ tabelle: 'pflege_objekt', spalte: 'id', id: o.id, adr });
    }

    let erledigt = 0;
    const nichtGefunden: string[] = [];
    for (const a of offen.slice(0, MAX)) {
      const url = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(a.adr)}&components=country:CH|country:LI&language=de&key=${key}`;
      const r = await (await fetch(url)).json();
      if (r.status === 'REQUEST_DENIED' || r.status === 'OVER_QUERY_LIMIT') {
        return json({ error: `Google: ${r.status} ${r.error_message || ''}`.trim(), erledigt, offen: offen.length - erledigt }, 502);
      }
      const loc = r.status === 'OK' ? r.results?.[0]?.geometry?.location : null;
      if (!loc) nichtGefunden.push(a.adr);
      const { error } = await admin.from(a.tabelle).update({
        lat: loc?.lat ?? null, lon: loc?.lng ?? null, geo_adresse: a.adr, geo_ok: !!loc,
      }).eq(a.spalte, a.id);
      if (error) return json({ error: error.message, erledigt, offen: offen.length - erledigt }, 500);
      erledigt++;
    }
    return json({ erledigt, offen: offen.length - erledigt, nicht_gefunden: nichtGefunden });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
