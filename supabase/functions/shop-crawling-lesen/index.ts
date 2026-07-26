// ============================================================================
// Offertentool 2027 - Shop-Crawling: Merkliste eines Lieferanten-Webshops
// lesen (erster echter Lieferant: Koi-Breeder, Gambio-Shop).
//
// Loggt sich serverseitig beim Webshop des Lieferanten ein (Login-Daten aus
// lieferant_datenabgleich.sync_verbindung, Passwort kommt entschluesselt aus
// dem Supabase Vault ueber die RPC lese_shop_passwort - nie im Klartext in
// der DB oder im Browser). Danach wird die angegebene Merklisten-Seite
// abgerufen und die enthaltenen Artikel (Bezeichnung/Artikelnummer/Preis)
// herausgeparst. Schreibt NICHTS in den Webshop zurueck.
//
// Diese Login-/Parsing-Logik ist bewusst Gambio-spezifisch (Login-Feldnamen
// email_address_login/password_login, POST auf login.php?action=process,
// Produktkarten als div.product-item mit "Artikel Nr.:"/"CHF "-Textmustern
// und dem Produktname im alt-Attribut des Bilds) - jeder weitere Lieferant
// mit anderer Shop-Software braucht eine eigene Variante.
//
// Aufruf vom Client: sb.functions.invoke('shop-crawling-lesen', { body: { lieferant_id, url } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

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

function parseZahl(text: string): number | null {
  if (!text) return null;
  let s = String(text).trim().replace(/['\s]/g, '');
  if (/,\d{1,2}$/.test(s)) s = s.replace(/\./g, '').replace(',', '.');
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}

// Sammelt Set-Cookie-Werte ueber mehrere Anfragen hinweg (einfacher
// Cookie-Jar als Name->Wert-Map, damit z.B. eine Session-Cookie von der
// Login-Seite selbst auch beim eigentlichen Login-POST mitgeschickt wird).
function sammleCookies(jar: Map<string, string>, res: Response) {
  const setCookie = typeof (res.headers as any).getSetCookie === 'function'
    ? (res.headers as any).getSetCookie()
    : (res.headers.get('set-cookie') ? [res.headers.get('set-cookie') as string] : []);
  for (const c of setCookie) {
    const [paar] = c.split(';');
    const gleich = paar.indexOf('=');
    if (gleich > 0) jar.set(paar.slice(0, gleich).trim(), paar.slice(gleich + 1).trim());
  }
}
function cookieHeader(jar: Map<string, string>): string {
  return Array.from(jar.entries()).map(([k, v]) => `${k}=${v}`).join('; ');
}

function parseGambioMerkliste(html: string) {
  const artikel: { artikelnummer_lieferant: string; bezeichnung: string; ep_lieferant: number | null }[] = [];
  const teile = html.split('class="product-item"');
  for (let i = 1; i < teile.length; i++) {
    const block = teile[i];
    const altMatch = block.match(/alt="([^"]+)"/);
    const nrMatch = block.match(/Artikel Nr\.:\s*([\d.]+)/);
    const preisMatch = block.match(/CHF\s*([\d'.,]+)/);
    if (!altMatch || !nrMatch) continue;
    artikel.push({
      artikelnummer_lieferant: nrMatch[1].trim(),
      bezeichnung: altMatch[1].trim(),
      ep_lieferant: preisMatch ? parseZahl(preisMatch[1]) : null,
    });
  }
  return artikel;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { lieferant_id, url } = await req.json().catch(() => ({}));
    if (!lieferant_id || !url) {
      return json({ error: 'lieferant_id und url sind erforderlich.' }, 400);
    }

    // Client mit dem Auth-Header des aufrufenden Nutzers erstellen, damit die
    // admin-only RPC lese_shop_passwort() korrekt unter dessen Identitaet laeuft.
    const authHeader = req.headers.get('Authorization') || '';
    const sb = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: da, error: daErr } = await sb
      .from('lieferant_datenabgleich')
      .select('sync_verbindung')
      .eq('lieferant_id', lieferant_id)
      .single();
    if (daErr || !da) return json({ error: 'Verbindungsdaten fuer diesen Lieferanten nicht gefunden.' }, 400);

    const verbindung = da.sync_verbindung || {};
    const shopUrl = verbindung.shop_url;
    const benutzername = verbindung.benutzername;
    if (!shopUrl || !benutzername) {
      return json({ error: 'Shop-URL oder Benutzername fehlt in den Verbindungsdaten.' }, 400);
    }

    const { data: passwort, error: pwErr } = await sb.rpc('lese_shop_passwort', { p_lieferant_id: lieferant_id });
    if (pwErr) return json({ error: 'Shop-Passwort konnte nicht gelesen werden: ' + pwErr.message }, 400);
    if (!passwort) return json({ error: 'Fuer diesen Lieferanten ist noch kein Shop-Passwort hinterlegt.' }, 400);

    let origin: string;
    try {
      origin = new URL(shopUrl).origin;
    } catch (_e) {
      return json({ error: 'Shop-URL ist ungueltig.' }, 400);
    }

    const cookieJar = new Map<string, string>();

    // 1) Login-Seite einmal laden, um eine anfaengliche Session-Cookie zu bekommen.
    const loginSeite = await fetch(`${origin}/login.php`, { redirect: 'manual' });
    sammleCookies(cookieJar, loginSeite);

    // 2) Login-Formular absenden (Gambio: email_address_login/password_login).
    const loginRes = await fetch(`${origin}/login.php?action=process`, {
      method: 'POST',
      redirect: 'manual',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Cookie: cookieHeader(cookieJar),
      },
      body: new URLSearchParams({ email_address_login: benutzername, password_login: passwort }),
    });
    sammleCookies(cookieJar, loginRes);

    // 3) Die eigentliche Merkliste mit der (hoffentlich eingeloggten) Session abrufen.
    const listeRes = await fetch(url, { headers: { Cookie: cookieHeader(cookieJar) } });
    if (!listeRes.ok) {
      return json({ error: `Merkliste konnte nicht geladen werden (Status ${listeRes.status}).` }, 400);
    }
    const html = await listeRes.text();
    if (html.includes('name="email_address_login"')) {
      return json({ error: 'Login beim Webshop fehlgeschlagen - bitte Benutzername/Passwort in den Verbindungsdaten pruefen.' }, 400);
    }

    const artikel = parseGambioMerkliste(html);
    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
