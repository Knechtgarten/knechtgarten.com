// ============================================================================
// Offertentool 2027 - Shop-Crawling fuer Lieferanten mit "Dabag"-Webshop
// (erster Fall: B-Team Bern). Erkennbar an CSS-Klassen wie "dabagTooltipLocal"
// und der Bilder-Domain "bilder.dabag.ch".
//
// Besonderheit bei diesem Shop: die Merkliste ("Favoriten") zeigt KEINE
// Preise - nur Artikelnummer, Bezeichnung, EAN, Menge. Preise (Richtpreis,
// Rabatt, Netto-Preis, Total) erscheinen erst im Firmenwarenkorb. Darum wird
// hier bewusst NICHT die Merkliste gelesen, sondern der Warenkorb
// (?srv=basket&companyYN=1) - der Nutzer legt die zu synchronisierenden
// Artikel selbst in den Warenkorb, statt in eine Merkliste.
//
// Anker pro Artikel: <tr id="bsi-NNNNNNNN" class="bsi-row ..."> - die Zahl
// direkt nach "bsi-" ist eindeutig pro Artikel-Zeile. Die zugehoerige
// "Kommission"-Zusatzzeile hat die Id "bsi-kommission-NNNNNNNN" (Buchstaben
// statt Ziffern direkt nach "bsi-"), wird von der Ankerregel darum nicht
// faelschlich als eigener Artikel erkannt.
//
// Preis: "Netto-Preis" (data-title="Netto-Preis") ist der tatsaechliche
// Einkaufspreis nach Rabatt vom "Richtpreis" (Listenpreis) - wir wollen den
// Netto-Preis als ep_lieferant.
//
// Aufruf vom Client: sb.functions.invoke('shop-crawling-dabag-lesen', { body: { lieferant_id, url } })
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

// Bild einmalig vom Lieferanten-Shop herunterladen und in unseren eigenen
// Storage-Bucket spiegeln (gleiches Muster wie bei den anderen Shop-Crawlern).
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

// Jeder Warenkorb-Artikel beginnt eindeutig mit
// "<tr id="bsi-NNNNNNNN" class="bsi-row" - die zugehoerige Kommission-
// Zusatzzeile heisst "bsi-kommission-NNNNNNNN" (kein \d+ direkt nach "bsi-"),
// wird also von diesem Anker nicht erfasst.
function parseDabagWarenkorb(html: string, origin: string) {
  const artikel: { artikelnummer_lieferant: string; bezeichnung: string; ep_lieferant: number | null; foto_url: string | null }[] = [];

  const itemRegex = /<tr id="bsi-\d+" class="bsi-row/g;
  const positionen: number[] = [];
  let m: RegExpExecArray | null;
  while ((m = itemRegex.exec(html)) !== null) positionen.push(m.index);

  for (let i = 0; i < positionen.length; i++) {
    const block = html.slice(positionen[i], positionen[i + 1] ?? html.length);

    const nrMatch = block.match(/class="bsi-groessenr">\s*<a[^>]*>\s*<b>([^<]+)<\/b>/);
    if (!nrMatch) continue;

    const nameMatch = block.match(/class=['"]bsi-fakturatext['"]>([^<]+)<\/div>/);
    const bildMatch = block.match(/background-image:\s*url\('([^']+)'\)/);
    const preisMatch = block.match(/data-title="Netto-Preis">\s*([^<]+)<\/td>/);

    let fotoUrl: string | null = null;
    if (bildMatch) {
      try { fotoUrl = new URL(bildMatch[1], origin).href; } catch (_e) { fotoUrl = null; }
    }

    artikel.push({
      artikelnummer_lieferant: nrMatch[1].trim(),
      bezeichnung: (nameMatch ? nameMatch[1] : nrMatch[1]).trim(),
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
      return json({ error: 'Warenkorb-URL ist ungueltig.' }, 400);
    }

    const { data: session, error: sessErr } = await sb.rpc('lese_shop_session', { p_lieferant_id: lieferant_id });
    if (sessErr) return json({ error: 'Shop-Session konnte nicht gelesen werden: ' + sessErr.message }, 400);
    if (!session) {
      return json({ error: 'Fuer diesen Lieferanten ist noch keine Shop-Session hinterlegt. Bitte im Browser einloggen, eine Anfrage im Netzwerk-Tab per "Als cURL kopieren" kopieren und im Feld "Session (aus Browser kopiert)" einfügen.' }, 400);
    }

    // Der Firmenwarenkorb zeigt alle enthaltenen Artikel auf einer einzigen
    // Seite (keine Pagination noetig, anders als bei den grossen
    // Katalog-Merklisten anderer Shops).
    const seiteRes = await fetch(url, { headers: { ...browserHeaders, Cookie: String(session) } });
    if (!seiteRes.ok) {
      return json({ error: `Warenkorb-Seite konnte nicht geladen werden (Status ${seiteRes.status}).` }, 400);
    }
    const html = await seiteRes.text();

    const artikel = parseDabagWarenkorb(html, origin);

    if (artikel.length === 0 && !html.includes('bsi-row') && !html.includes('Firmenwarenkorb')) {
      return json({ error: 'Session abgelaufen oder ungueltig - bitte im Browser neu einloggen, "Als cURL kopieren" wiederholen und im Feld "Session (aus Browser kopiert)" neu einfügen.' }, 400);
    }

    // Fotos in kleinen Gruppen GLEICHZEITIG spiegeln (gleiches Muster wie bei
    // den anderen Shop-Crawlern) statt strikt nacheinander.
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
      const ankerPos = html.indexOf('id="bsi-');
      return json({
        artikel,
        debug: {
          htmlLaenge: html.length,
          hatBsiRow: html.includes('bsi-row'),
          ausschnittUmErstenItem: ankerPos !== -1 ? html.slice(Math.max(0, ankerPos - 60), ankerPos + 700) : null,
        },
      });
    }

    return json({ artikel });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
