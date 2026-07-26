// ============================================================================
// Offertentool 2027 - Shop-Crawling fuer Lieferanten mit Gambio-Webshop.
//
// Nicht pro Lieferant, sondern pro Shop-SOFTWARE: jeder Lieferant, dessen
// Webshop auf Gambio laeuft (erster Fall: Koi-Breeder), kann diese Funktion
// mitverwenden - Login-Formular und Produktkarten-Aufbau sind bei Gambio-
// Shops identisch. Ein Lieferant mit anderer Shop-Software (WooCommerce,
// Shopify, Eigenentwicklung, ...) braucht eine eigene Funktion nach gleichem
// Namensmuster (z.B. shop-crawling-woocommerce-lesen).
//
// Loggt sich serverseitig beim Webshop des Lieferanten ein (Login-Daten aus
// lieferant_datenabgleich.sync_verbindung, Passwort kommt entschluesselt aus
// dem Supabase Vault ueber die RPC lese_shop_passwort - nie im Klartext in
// der DB oder im Browser). Danach wird die angegebene Merklisten-Seite
// abgerufen und die enthaltenen Artikel (Bezeichnung/Artikelnummer/Preis)
// herausgeparst. Produktbilder werden dabei einmalig heruntergeladen und in
// den eigenen Storage-Bucket "artikel-fotos" gespiegelt (nicht nur verlinkt),
// damit sie erhalten bleiben, falls der Lieferant sie im Shop spaeter aendert
// oder loescht. Schreibt sonst NICHTS in den Webshop zurueck.
//
// Gambio-spezifisch: Login-Feldnamen email_address_login/password_login,
// POST auf login.php?action=process, Produktkarten als div.product-item mit
// "Artikel Nr.:"/"CHF "-Textmustern und dem Produktname im alt-Attribut des Bilds.
//
// Aufruf vom Client: sb.functions.invoke('shop-crawling-gambio-lesen', { body: { lieferant_id, url } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// Ohne diese Header sieht eine Anfrage fuer den Ziel-Shop nicht wie ein
// normaler Browser aus (kein User-Agent etc.) - manche Shops/Hoster
// blockieren oder verweigern den Login bzw. Bild-Abruf dann unabhaengig
// davon, ob Benutzername/Passwort stimmen.
const browserHeaders = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
  'Accept-Language': 'de-CH,de;q=0.9',
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

// Bild einmalig vom Lieferanten-Shop herunterladen und in unseren eigenen
// Storage-Bucket spiegeln (gleicher Bucket wie beim manuellen Foto-Upload in
// Tool C), statt nur extern zu verlinken - so bleibt das Bild auch dann
// erhalten, wenn der Lieferant es spaeter im Shop loescht/verschiebt. Schlaegt
// der Download/Upload fehl, wird ehrlich der externe Link als Rueckfallwert
// behalten statt den ganzen Abgleich abzubrechen.
async function spiegleFotoInStorage(sb: any, fotoUrl: string): Promise<string> {
  try {
    const bildRes = await fetch(fotoUrl, { headers: browserHeaders });
    if (!bildRes.ok) return fotoUrl;
    const bytes = new Uint8Array(await bildRes.arrayBuffer());
    const contentType = bildRes.headers.get('content-type') || 'image/jpeg';
    const ext = (fotoUrl.split('?')[0].split('.').pop() || 'jpg').toLowerCase().slice(0, 5);
    const pfad = `${crypto.randomUUID()}.${ext}`;
    const { error: upErr } = await sb.storage.from('artikel-fotos').upload(pfad, bytes, { contentType });
    if (upErr) return fotoUrl;
    const { data } = sb.storage.from('artikel-fotos').getPublicUrl(pfad);
    return data?.publicUrl || fotoUrl;
  } catch (_e) {
    return fotoUrl;
  }
}

// Diagnose, WARUM ein Login fehlschlaegt - unterscheidet "der Shop hat uns
// tatsaechlich abgelehnt" von "wir wurden vorher schon von einer Firewall/
// einem unsichtbaren Bot-Check ausgebremst", was mit reinen HTTP-Anfragen
// (ohne echten Browser) grundsaetzlich nicht loesbar waere.
function erkenneVerdaechtigeAntwort(html: string): string | null {
  const h = html.toLowerCase();
  if (h.includes('recaptcha') || h.includes('g-recaptcha')) {
    return 'Die Seite enthaelt ein reCAPTCHA - der Shop verlangt offenbar eine unsichtbare Bot-Pruefung, die ein reiner Server-Aufruf (ohne echten Browser) nicht loesen kann.';
  }
  if (h.includes('cloudflare') && (h.includes('attention required') || h.includes('checking your browser') || h.includes('cf-error') || h.includes('ray id'))) {
    return 'Die Antwort kommt von einem Cloudflare-Sicherheitscheck, nicht vom Shop selbst - die Anfrage wurde schon davor blockiert.';
  }
  if (h.includes('access denied') || h.includes('forbidden') || h.includes('blockiert') || h.includes('gesperrt')) {
    return 'Die Antwort deutet auf eine Zugriffssperre (Firewall/Hosting) hin, nicht auf falsche Zugangsdaten.';
  }
  if (h.includes('too many requests') || h.includes('rate limit') || h.includes('zu viele anfragen')) {
    return 'Die Antwort deutet auf eine Rate-Limit-Sperre hin (zu viele Versuche in kurzer Zeit).';
  }
  return null;
}

function parseGambioMerkliste(html: string, origin: string) {
  const artikel: { artikelnummer_lieferant: string; bezeichnung: string; ep_lieferant: number | null; foto_url: string | null }[] = [];
  const teile = html.split('class="product-item"');
  for (let i = 1; i < teile.length; i++) {
    const block = teile[i];
    const imgTagMatch = block.match(/<img[^>]*>/);
    const imgTag = imgTagMatch ? imgTagMatch[0] : '';
    const altMatch = imgTag.match(/alt="([^"]+)"/);
    const srcMatch = imgTag.match(/src="([^"]+)"/);
    const nrMatch = block.match(/Artikel Nr\.:\s*([\d.]+)/);
    const preisMatch = block.match(/CHF\s*([\d'.,]+)/);
    if (!altMatch || !nrMatch) continue;
    let fotoUrl: string | null = null;
    if (srcMatch) {
      try { fotoUrl = new URL(srcMatch[1], origin).href; } catch (_e) { fotoUrl = null; }
    }
    artikel.push({
      artikelnummer_lieferant: nrMatch[1].trim(),
      bezeichnung: altMatch[1].trim(),
      ep_lieferant: preisMatch ? parseZahl(preisMatch[1]) : null,
      foto_url: fotoUrl,
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
    if (!shopUrl) {
      return json({ error: 'Shop-URL fehlt in den Verbindungsdaten.' }, 400);
    }

    let origin: string;
    try {
      origin = new URL(shopUrl).origin;
    } catch (_e) {
      return json({ error: 'Shop-URL ist ungueltig.' }, 400);
    }

    // Manche Shops pruefen beim Login ein unsichtbares reCAPTCHA, das ein
    // reiner Server-Aufruf nicht bestehen kann - dafuer gibt es die per Hand
    // aus dem Browser kopierte Session (siehe lieferant-abgleich-live-v1.html,
    // Feld "Session (aus Browser kopiert)"). Ist eine gespeichert, wird sie
    // direkt verwendet und der eigene Login-Versuch komplett uebersprungen.
    const { data: session, error: sessErr } = await sb.rpc('lese_shop_session', { p_lieferant_id: lieferant_id });
    if (sessErr) return json({ error: 'Shop-Session konnte nicht gelesen werden: ' + sessErr.message }, 400);

    const cookieJar = new Map<string, string>();
    let loginResHtml = '';
    let loginResStatus = 0;

    if (session) {
      for (const paar of String(session).split(';')) {
        const gleich = paar.indexOf('=');
        if (gleich > 0) cookieJar.set(paar.slice(0, gleich).trim(), paar.slice(gleich + 1).trim());
      }
    } else {
      if (!benutzername) {
        return json({ error: 'Weder Benutzername/Passwort noch eine gespeicherte Session sind fuer diesen Lieferanten hinterlegt.' }, 400);
      }
      const { data: passwort, error: pwErr } = await sb.rpc('lese_shop_passwort', { p_lieferant_id: lieferant_id });
      if (pwErr) return json({ error: 'Shop-Passwort konnte nicht gelesen werden: ' + pwErr.message }, 400);
      if (!passwort) return json({ error: 'Fuer diesen Lieferanten ist noch kein Shop-Passwort hinterlegt.' }, 400);

      // 1) Login-Seite einmal laden, um eine anfaengliche Session-Cookie zu bekommen.
      const loginSeite = await fetch(`${origin}/login.php`, { redirect: 'manual', headers: browserHeaders });
      sammleCookies(cookieJar, loginSeite);

      // 2) Login-Formular absenden (Gambio: email_address_login/password_login).
      const loginRes = await fetch(`${origin}/login.php?action=process`, {
        method: 'POST',
        redirect: 'manual',
        headers: {
          ...browserHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
          Referer: `${origin}/login.php`,
          Cookie: cookieHeader(cookieJar),
        },
        body: new URLSearchParams({ email_address_login: benutzername, password_login: passwort }),
      });
      sammleCookies(cookieJar, loginRes);
      loginResHtml = await loginRes.clone().text().catch(() => '');
      loginResStatus = loginRes.status;
    }

    // 3) Die eigentliche Merkliste mit der (hoffentlich eingeloggten) Session abrufen.
    const listeRes = await fetch(url, { headers: { ...browserHeaders, Cookie: cookieHeader(cookieJar) } });
    if (!listeRes.ok) {
      return json({ error: `Merkliste konnte nicht geladen werden (Status ${listeRes.status}).` }, 400);
    }
    const html = await listeRes.text();
    if (html.includes('name="email_address_login"')) {
      if (session) {
        return json({ error: 'Session abgelaufen - bitte im Browser neu einloggen, "Als cURL kopieren" wiederholen und im Feld "Session (aus Browser kopiert)" neu einfügen.' }, 400);
      }
      const verdacht = erkenneVerdaechtigeAntwort(loginResHtml) || erkenneVerdaechtigeAntwort(html);
      const zusatz = verdacht
        ? ` (${verdacht})`
        : ` (Login-Antwort-Status war ${loginResStatus} - Shop hat wieder die normale Login-Seite gezeigt, kein erkennbarer Bot-Check im HTML gefunden.)`;
      return json({ error: `Login beim Webshop fehlgeschlagen - bitte Benutzername/Passwort in den Verbindungsdaten pruefen.${zusatz}` }, 400);
    }

    const artikel = parseGambioMerkliste(html, origin);
    for (const a of artikel) {
      if (a.foto_url) a.foto_url = await spiegleFotoInStorage(sb, a.foto_url);
    }
    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
