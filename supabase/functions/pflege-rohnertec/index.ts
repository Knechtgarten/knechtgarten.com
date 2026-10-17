// ============================================================================
// Pflege-Tool - Bewaesserungsplaene aus Rohnertec uebernehmen (bei Rohnertec nur lesen)
//
// Meldet sich mit dem Partner-Login (Secrets ROHNERTEC_EMAIL / ROHNERTEC_PASSWORD)
// bei Rohnertec an, liest pro Endkunde Ventile, zugehoerige Sensoren (gemeinsamer
// Gruenbereich) und die zyklischen Handlungen und schreibt daraus den
// Bewaesserungsplan in pflege_kunde_kategorie.bewaesserung (Hauptadresse, Kategorie
// mit sondertabelle = 'bewaesserung'). Zuordnung Kunde <-> Rohnertec ueber
// pflege_kunde.rohnertec_id.
//
// Rohnertec hat keine offizielle API; genutzt wird die Schnittstelle des Portals.
// Bei Rohnertec wird nie etwas geaendert.
//
//   { aktion: 'abgleich' }                       -> alle Rohnertec-Kunden
//   { aktion: 'abgleich', rohnertec_id: 458 }    -> nur dieser Kunde
//   Antwort: { stand, kunden: [{ rohnertec_id, name, ort, status, ventile, kunde_id }] }
//     status: 'geaendert' | 'gleich' | 'nicht_verknuepft' | 'ohne_bewaesserung'
//
// Nur fuer freigeschaltete, aktive Benutzer - serverseitig geprueft. Geschrieben
// wird mit den Rechten des Aufrufers (RLS wie im Tool).
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const RT = 'https://admin.rohnertec.swiss/';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

async function rohnertecToken(): Promise<string> {
  const email = Deno.env.get('ROHNERTEC_EMAIL'), password = Deno.env.get('ROHNERTEC_PASSWORD');
  if (!email || !password) throw new Error('Rohnertec-Zugang fehlt (ROHNERTEC_EMAIL / ROHNERTEC_PASSWORD in Supabase hinterlegen).');
  const res = await fetch(RT + 'login', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
  const d = await res.json().catch(() => ({}));
  const token = d?.jwt_data?.jwt_token;
  if (!res.ok || !token) throw new Error('Anmeldung bei Rohnertec fehlgeschlagen (Zugangsdaten prüfen).');
  return token;
}

// Vergleich unabhaengig von der Feldreihenfolge (jsonb sortiert Schluessel um)
const kanon = (x: any): any => Array.isArray(x) ? x.map(kanon)
  : x && typeof x === 'object' ? Object.fromEntries(Object.keys(x).sort().map(k => [k, kanon(x[k])])) : x;
const dm = (d: string | null) => d ? `${+d.slice(8, 10)}.${+d.slice(5, 7)}.` : '';
const sauber = (s: string) => (s || '').trim().replace(/\s+/g, ' ');

// Ventile eines Rohnertec-Kunden -> Bewaesserungsplan
async function planVon(get: (u: string) => Promise<any>, clientId: number) {
  const [sen, ven] = await Promise.all([
    get(`client-sensors-table?user_id=${clientId}&offset=0&rownum=200&sorting=`).then(r => r?.[1] || []),
    get(`client-valves-table?user_id=${clientId}&offset=0&rownum=200&sorting=`).then(r => r?.[1] || []),
  ]);
  // Rohnertec liefert die Ventile nach letzter Messung sortiert -> fest nach Name ordnen (stabil, gut lesbar)
  ven.sort((x: any, y: any) => sauber(x.valve_name).localeCompare(sauber(y.valve_name), 'de', { numeric: true }));
  return Promise.all(ven.map(async (v: any) => {
    const [det, ai] = await Promise.all([get(`valve-by-id-details/${v.uuid}`), get(`valve/auto-irrigation/${v.uuid}`)]);
    const d = det?.data || {}, a = ai?.data || {};
    // Sensor = gleicher Gruenbereich: zuerst genaue Zone (container), sonst Oberzone (greenzone)
    const cont = new Set(d.assignment?.container_names || []);
    const gz = new Set([...(d.assignment?.greenzone_names || []), d.greenzone_name].filter(Boolean));
    let s = sen.filter((x: any) => (x.assignment?.container_names || []).some((z: string) => cont.has(z)));
    if (!s.length) s = sen.filter((x: any) => [...(x.assignment?.greenzone_names || []), x.greenzone_name].some((z: string) => gz.has(z)));
    // Muster = gleiche Zeit, Grenzwert und Zeitraum; Tage zusammengefasst (0 = Mo)
    const gr: Record<string, any> = {}, temp = new Set<string>();
    for (const z of (a.auto_irrigation_cycles || []).filter((x: any) => x.is_enabled)) {
      const von = z.time_from.slice(0, 5), bis = z.time_until.slice(0, 5);
      if (z.capability_id === 1) temp.add(`${von}–${bis} nach Temperatur ${z.threshold} °C`);
      const gw = z.capability_id === 2 ? z.threshold : null;
      const zr = z.active_from || z.active_until ? `${dm(z.active_from)}–${dm(z.active_until)}` : '';
      const key = [von, bis, gw, zr].join('|');
      (gr[key] = gr[key] || { von, bis, tage: [], gw, zr }).tage.push(z.weekday_id - 1);
    }
    const muster = Object.values(gr).map((m: any) => ({ ...m, tage: [...new Set(m.tage as number[])].sort((x, y) => x - y) }))
      .sort((x: any, y: any) => (Number(!!x.zr) - Number(!!y.zr)) || (y.tage.length - x.tage.length) || x.von.localeCompare(y.von));
    return { rt: v.uuid, name: sauber(v.valve_name), sensor: [...new Set(s.map((x: any) => sauber(x.sensor_name)))].join(', '), bem: [...temp].join('; '), muster };
  }));
}

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

    const { aktion, rohnertec_id } = await req.json().catch(() => ({}));
    if (aktion !== 'abgleich') return json({ error: 'Unbekannte Aktion.' }, 400);

    const token = await rohnertecToken();
    const get = async (u: string) => {
      const r = await fetch(RT + u, { headers: { Authorization: `Bearer ${token}` } });
      if (!r.ok) throw new Error(`Rohnertec antwortet nicht wie erwartet (${r.status}).`);
      return r.json();
    };

    let kunden = (await get('reseller-clients-management-table?&offset=0&rownum=500&sorting='))?.[1] || [];
    if (rohnertec_id) kunden = kunden.filter((c: any) => c.client_id === +rohnertec_id);
    if (rohnertec_id && !kunden.length) return json({ error: 'Kunde in Rohnertec nicht gefunden.' }, 404);

    const { data: kat } = await sb.from('pflege_kategorie').select('id').eq('sondertabelle', 'bewaesserung').maybeSingle();
    const { data: verkn } = await sb.from('pflege_kunde').select('kunde_id,rohnertec_id').not('rohnertec_id', 'is', null);
    const kundeVon = new Map((verkn || []).map((x: any) => [x.rohnertec_id, x.kunde_id]));

    const stand = new Date().toISOString(), aus: any[] = [];
    for (const c of kunden) {
      const zeile: any = { rohnertec_id: c.client_id, name: sauber(c.client_name), ort: (c.full_location_name || '').replace(/, CH$/, ''), kunde_id: kundeVon.get(c.client_id) || null };
      if (!zeile.kunde_id) { aus.push({ ...zeile, status: 'nicht_verknuepft' }); continue; }
      const { data: kk } = await sb.from('pflege_kunde_kategorie').select('id,bewaesserung')
        .eq('kunde_id', zeile.kunde_id).eq('kategorie_id', kat?.id).is('objekt_id', null).maybeSingle();
      if (!kk) { aus.push({ ...zeile, status: 'ohne_bewaesserung' }); continue; }
      const plan = await planVon(get, c.client_id);
      const geaendert = JSON.stringify(kanon(plan)) !== JSON.stringify(kanon(kk.bewaesserung || []));
      const { error } = await sb.from('pflege_kunde_kategorie').update({ bewaesserung: plan, bewaesserung_stand: stand }).eq('id', kk.id);
      if (error) throw error;
      aus.push({ ...zeile, status: geaendert ? 'geaendert' : 'gleich', ventile: plan.length });
    }
    return json({ stand, kunden: aus });
  } catch (e) {
    console.error(e);
    return json({ error: (e as Error).message || String(e) }, 500);
  }
});
