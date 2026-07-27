// ============================================================================
// Offertentool 2027 - Shop-Crawling fuer Lieferanten mit SAP-Commerce-/
// Hybris-Webshop (erster Fall: HGC).
//
// Anders als bei Gambio/Magento ist hier keine Regex-Fensterung ueber
// einzelne HTML-Bloecke noetig: die Favoriten-Liste steckt als sauberes JSON
// direkt in der Seite, eingebettet in einem <script>-Tag als
// "window.initialData['favorites/data'] = {...}" (kein schliessendes
// Semikolon - das Objekt endet direkt vor "</script>"). Dieses Objekt wird
// per JSON.parse() ausgelesen statt mit Text-Mustern durchsucht.
//
// Preis: "volumePrices" ist der Netto-/Kommissionspreis (dieser Account hat
// die Berechtigung "displayNettoPricesGroup"), "volumePricesGross" waere der
// gleiche Preis inkl. MwSt. - wir wollen den Nettopreis als Einkaufspreis.
//
// Foto: pro Artikel gibt es mehrere Groessen in "image.medias" (categoryXS/S/
// M/XXS-Varianten mit "mediaFormat"-Feld) plus genau ein Original-/
// Hauptbild ganz ohne "mediaFormat"-Feld - dieses wird bevorzugt verwendet.
//
// Session-Handling: wie bei Gambio/Magento wird eine per Hand aus dem
// Browser kopierte Session (Vault-RPC lese_shop_session) verwendet, da auch
// hier ein Login noetig ist.
//
// Aufruf vom Client: sb.functions.invoke('shop-crawling-hybris-lesen', { body: { lieferant_id, url } })
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

// Bild einmalig vom Lieferanten-Shop herunterladen und in unseren eigenen
// Storage-Bucket spiegeln (gleiches Muster wie bei Gambio/Magento) - bleibt
// so erhalten, falls der Lieferant es im Shop spaeter loescht/verschiebt.
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

// Extrahiert das eingebettete JSON-Objekt aus
// "window.initialData['favorites/data'] = {...}</script>".
function extrahiereFavoritenJson(html: string): any {
  const anker = "window.initialData['favorites/data'] = ";
  const start = html.indexOf(anker);
  if (start === -1) return null;
  const jsonStart = start + anker.length;
  const ende = html.indexOf('</script>', jsonStart);
  if (ende === -1) return null;
  const roh = html.slice(jsonStart, ende).trim().replace(/;$/, '');
  try {
    return JSON.parse(roh);
  } catch (_e) {
    return null;
  }
}

function parseHybrisFavoriten(favoritenJson: any, origin: string) {
  const artikel: { artikelnummer_lieferant: string; bezeichnung: string; ep_lieferant: number | null; foto_url: string | null }[] = [];
  const entries = favoritenJson?.data?.favoritesList?.entries;
  if (!Array.isArray(entries)) return artikel;

  for (const e of entries) {
    if (!e?.code) continue;

    const nettoPreis = Array.isArray(e.volumePrices) && e.volumePrices.length > 0
      ? e.volumePrices[0].value
      : null;

    const medias = e.image?.medias;
    let bildUrl: string | null = null;
    if (Array.isArray(medias) && medias.length > 0) {
      const hauptbild = medias.find((m: any) => !m.mediaFormat) || medias[0];
      bildUrl = hauptbild?.url || null;
    }
    let fotoUrl: string | null = null;
    if (bildUrl) {
      try { fotoUrl = new URL(bildUrl, origin).href; } catch (_e) { fotoUrl = null; }
    }

    artikel.push({
      artikelnummer_lieferant: String(e.code).trim(),
      bezeichnung: String(e.name || e.code).trim(),
      ep_lieferant: typeof nettoPreis === 'number' ? nettoPreis : null,
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
      return json({ error: 'Favoriten-URL ist ungueltig.' }, 400);
    }

    const { data: session, error: sessErr } = await sb.rpc('lese_shop_session', { p_lieferant_id: lieferant_id });
    if (sessErr) return json({ error: 'Shop-Session konnte nicht gelesen werden: ' + sessErr.message }, 400);
    if (!session) {
      return json({ error: 'Fuer diesen Lieferanten ist noch keine Shop-Session hinterlegt. Bitte im Browser einloggen, eine Anfrage im Netzwerk-Tab per "Als cURL kopieren" kopieren und im Feld "Session (aus Browser kopiert)" einfügen.' }, 400);
    }

    // Anders als bei Gambio/Magento gibt es hier keine Seiten-Pagination -
    // die komplette Favoriten-Liste steckt schon im ersten Seitenaufruf.
    const seiteRes = await fetch(url, { headers: { ...browserHeaders, Cookie: String(session) } });
    if (!seiteRes.ok) {
      return json({ error: `Favoriten-Seite konnte nicht geladen werden (Status ${seiteRes.status}).` }, 400);
    }
    const html = await seiteRes.text();

    const favoritenJson = extrahiereFavoritenJson(html);
    if (!favoritenJson) {
      return json({ error: 'Session abgelaufen oder ungueltig - bitte im Browser neu einloggen, "Als cURL kopieren" wiederholen und im Feld "Session (aus Browser kopiert)" neu einfügen.' }, 400);
    }

    const artikel = parseHybrisFavoriten(favoritenJson, origin);

    // Fotos in kleinen Gruppen GLEICHZEITIG spiegeln statt strikt
    // nacheinander (gleiches Muster wie bei Gambio/Magento, wegen der
    // Supabase-Timeout-Grenze bei vielen Artikeln).
    const FOTO_GRUPPENGROESSE = 8;
    for (let i = 0; i < artikel.length; i += FOTO_GRUPPENGROESSE) {
      const gruppe = artikel.slice(i, i + FOTO_GRUPPENGROESSE);
      await Promise.all(gruppe.map(async (a) => {
        if (a.foto_url) a.foto_url = await spiegleFotoInStorage(sb, a.foto_url);
      }));
    }

    // Werden 0 Artikel gefunden, gleich einen Blick auf das tatsaechlich
    // abgerufene HTML mitliefern, statt nochmal ueber Browser-Screenshots
    // raten zu muessen, was der Server wirklich bekommen hat.
    if (artikel.length === 0) {
      return json({
        artikel,
        debug: {
          htmlLaenge: html.length,
          hatFavoritenAnker: html.includes("window.initialData['favorites/data']"),
          entriesGefunden: Array.isArray(favoritenJson?.data?.favoritesList?.entries)
            ? favoritenJson.data.favoritesList.entries.length
            : null,
        },
      });
    }

    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
