// ============================================================================
// Offertentool 2027 - Distance-Matrix-Proxy
//
// Googles Distance-Matrix-Web-Service-API liefert keine
// Access-Control-Allow-Origin-Header - ein direkter Aufruf aus dem Browser
// (fetch) wird darum von jedem Browser als CORS-Fehler blockiert, auch wenn
// Key und Adresse völlig in Ordnung sind. Diese Function ruft Google
// stattdessen serverseitig auf (kein Browser, kein CORS-Problem) und gibt
// die Antwort unveraendert weiter. Haelt den API-Key ausserdem serverseitig
// geheim statt im Client-Code sichtbar zu sein.
//
// Aufruf vom Client: sb.functions.invoke('distance-matrix', { body: { origin, destination } })
// ============================================================================

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
    const { origin, destination } = await req.json().catch(() => ({}));
    if (!origin || !destination) {
      return json({ error: 'origin und destination sind erforderlich.' }, 400);
    }

    const apiKey = Deno.env.get('GOOGLE_MAPS_API_KEY');
    if (!apiKey) {
      return json({ error: 'GOOGLE_MAPS_API_KEY ist auf dem Server nicht konfiguriert.' }, 500);
    }

    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destination)}&key=${apiKey}`;
    const res = await fetch(url);
    const data = await res.json();
    return json(data);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
