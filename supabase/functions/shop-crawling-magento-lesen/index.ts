// ============================================================================
// Offertentool 2027 - Shop-Crawling fuer Lieferanten mit Magento-2-Webshop.
//
// Analog zu shop-crawling-gambio-lesen (siehe dort fuer die Grund-Idee: pro
// Shop-SOFTWARE eine eigene Funktion, nicht pro Lieferant). Erster Fall:
// Aqua-Technik-Shop.
//
// Wichtiger Unterschied zu Gambio: die oeffentlichen Katalogseiten von
// Magento-Shops sind meist ohne Login lesbar - ABER die dort gezeigten Preise
// sind reine Listenpreise. Eingeloggte Geschaeftskunden sehen ihre eigenen
// Konditionen (Netto-/Sonderpreise), und genau die brauchen wir fuer den
// Einkaufspreis-Abgleich. Darum wird trotzdem eine eingeloggte Session
// benoetigt, genau wie bei Gambio. Da auch hier beim Login ein reCAPTCHA
// vorgeschaltet ist, wird - anders als bei Gambio - KEIN eigener Login-
// Versuch (Benutzername/Passwort) gebaut: nur die per Hand aus dem Browser
// kopierte Session wird unterstuetzt (gleiche Vault-RPC lese_shop_session
// wie bei Gambio, siehe lieferant-abgleich-live-v1.html, Feld "Session (aus
// Browser kopiert)").
//
// Merklisten-Struktur stammt von der Drittanbieter-Erweiterung "Amasty
// Wishlist" (URL-Pfad /mwishlist/...), per echtem outerHTML verifiziert:
// jeder Artikel ist ein eigener <li id="item_NNNN" class="amwishlist-item">-
// Block mit Foto (<img class="product-image-photo" src="...">, keine Lazy-
// Load-Attribut-Falle hier), Name (<a class="amwishlist-name" title="...">),
// Preis (data-price-type="finalPrice" data-price-amount="...") und
// Artikelnummer (versteckt in einem Tooltip: <dt>Art.Nr.</dt><dd>...</dd>).
//
// Aufruf vom Client: sb.functions.invoke('shop-crawling-magento-lesen', { body: { lieferant_id, url } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

// Das rohe Server-HTML dieses Shops schreibt Sonderzeichen in Attributwerten
// (z.B. Leerzeichen im Produktnamen) als HTML-Entities statt als echtes
// Zeichen - z.B. "Rain&#x20;Bird&#x20;..." statt "Rain Bird ...". Chromes
// "Copy outerHTML" zeigt das schon aufgeloest (deshalb ist das beim ersten
// Test nicht aufgefallen), das rohe HTML, das unser Server bekommt, aber nicht.
function entHtmlDecode(text: string): string {
  return text
    .replace(/&#x([0-9a-fA-F]+);/g, (_m, hex) => String.fromCharCode(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_m, dec) => String.fromCharCode(parseInt(dec, 10)))
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>');
}

// Bild einmalig vom Lieferanten-Shop herunterladen und in unseren eigenen
// Storage-Bucket spiegeln (gleicher Bucket wie beim manuellen Foto-Upload in
// Tool C und bei der Gambio-Funktion) - bleibt so erhalten, falls der
// Lieferant es im Shop spaeter loescht/verschiebt. Schlaegt der Download/
// Upload fehl, wird ehrlich der externe Link als Rueckfallwert behalten.
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

// Jeder Merklisten-Artikel beginnt eindeutig mit
// "<li id="item_NNNN" class="amwishlist-item"" - anders als bei Gambio kommt
// dieses Muster garantiert nur einmal pro Artikel vor (die Drei-Punkte-Menue-
// Eintraege je Zeile sind zwar auch <li>-Elemente, aber ohne "item_"-Id),
// darum reicht ein einfacher Fenster-Schnitt von einem Treffer bis zum
// naechsten statt einer Div-Tiefen-Analyse.
function parseMagentoMerkliste(html: string, origin: string) {
  const artikel: { artikelnummer_lieferant: string; bezeichnung: string; ep_lieferant: number | null; foto_url: string | null }[] = [];

  const itemRegex = /<li\s+id="item_\d+"\s+class="amwishlist-item"/g;
  const positionen: number[] = [];
  let m: RegExpExecArray | null;
  while ((m = itemRegex.exec(html)) !== null) positionen.push(m.index);

  for (let i = 0; i < positionen.length; i++) {
    const block = html.slice(positionen[i], positionen[i + 1] ?? html.length);

    // Die Artikelnummer steckt nicht sichtbar in der Zeile, sondern in einem
    // Tooltip-Block ("Optionsdetails" -> "Art.Nr." -> Wert). Ohne sie koennen
    // wir den Artikel nicht unserem Artikelstamm zuordnen - dann ueberspringen.
    const nrMatch = block.match(/<dt\s+class="label">Art\.Nr\.<\/dt>\s*<dd\s+class="values">\s*([^<]+?)\s*<\/dd>/);
    if (!nrMatch) continue;

    const nameMatch = block.match(/<a\s+class="amwishlist-name"[^>]*title="([^"]+)"/);
    const bildMatch = block.match(/<img\s+class="product-image-photo"[^>]*src="([^"]+)"/);

    // Bevorzugt den "finalPrice" (tatsaechlich zu zahlender Preis inkl.
    // evtl. Sonderangebot) - nur falls der fehlt (Artikel ohne Sonderpreis-
    // Auszeichnung), den ersten im Block gefundenen Preis nehmen.
    const finalPreisMatch = block.match(/data-price-type="finalPrice"[^>]*data-price-amount="([\d.]+)"/)
      || block.match(/data-price-amount="([\d.]+)"[^>]*data-price-type="finalPrice"/);
    const irgendeinPreisMatch = block.match(/data-price-amount="([\d.]+)"/);
    const preisMatch = finalPreisMatch || irgendeinPreisMatch;

    let fotoUrl: string | null = null;
    if (bildMatch) {
      try { fotoUrl = new URL(bildMatch[1], origin).href; } catch (_e) { fotoUrl = null; }
    }

    artikel.push({
      artikelnummer_lieferant: entHtmlDecode(nrMatch[1]).trim(),
      bezeichnung: entHtmlDecode(nameMatch ? nameMatch[1] : nrMatch[1]).trim(),
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
    // admin-only RPC lese_shop_session() korrekt unter dessen Identitaet laeuft.
    const authHeader = req.headers.get('Authorization') || '';
    const sb = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    let origin: string;
    try {
      origin = new URL(url).origin;
    } catch (_e) {
      return json({ error: 'Merklisten-URL ist ungueltig.' }, 400);
    }

    const { data: session, error: sessErr } = await sb.rpc('lese_shop_session', { p_lieferant_id: lieferant_id });
    if (sessErr) return json({ error: 'Shop-Session konnte nicht gelesen werden: ' + sessErr.message }, 400);
    if (!session) {
      return json({ error: 'Fuer diesen Lieferanten ist noch keine Shop-Session hinterlegt. Bitte im Browser einloggen, eine Anfrage im Netzwerk-Tab per "Als cURL kopieren" kopieren und im Feld "Session (aus Browser kopiert)" einfügen.' }, 400);
    }

    const listeRes = await fetch(url, { headers: { ...browserHeaders, Cookie: String(session) } });
    if (!listeRes.ok) {
      return json({ error: `Merkliste konnte nicht geladen werden (Status ${listeRes.status}).` }, 400);
    }
    const html = await listeRes.text();

    if (!html.includes('amwishlist-item') || html.includes('login[username]')) {
      return json({ error: 'Session abgelaufen oder ungueltig - bitte im Browser neu einloggen, "Als cURL kopieren" wiederholen und im Feld "Session (aus Browser kopiert)" neu einfügen.' }, 400);
    }

    const artikel = parseMagentoMerkliste(html, origin);
    for (const a of artikel) {
      if (a.foto_url) a.foto_url = await spiegleFotoInStorage(sb, a.foto_url);
    }
    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
