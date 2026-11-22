// ============================================================================
// Sicherheitsdatenblatt-QR (ohne Anmeldung): knechtgarten.com/s/<code> → /sdb-qr.html?c=<code>
// Der Code steht auf dem gelben Kleber am Kanister (wissen_eintrag.sdb_code, 16 Zufallszeichen).
// Gibt nur dieses eine Produkt heraus: Name, Hersteller/Untertitel, UFI-Nummer, Foto, Schutzausrüstung,
// Verhaltensregeln/Erste Hilfe (sicherheit_html) und die Sicherheitsdatenblätter (bereich 'sicherheit')
// als kurz gültige signierte Links. Keine Preise, Notizen oder andere Produkte. Aufruf: POST { code }
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const BUCKET = 'wissen-dateien', GUELTIG = 3600 * 2;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const { code } = await req.json().catch(() => ({}));
    const c = String(code || '').toLowerCase();
    if (!/^[a-z0-9]{12,40}$/.test(c)) return json({ error: 'ungueltig' }, 404);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: e } = await sb.from('wissen_eintrag').select('id,titel,untertitel,ufi,titelfoto_pfad,psa,sicherheit_html')
      .eq('sdb_code', c).is('archiviert_am', null).maybeSingle();
    if (!e) return json({ error: 'ungueltig' }, 404);

    const { data: d } = await sb.from('wissen_datei').select('name,art,storage_pfad')
      .eq('eintrag_id', e.id).eq('bereich', 'sicherheit').is('exemplar_id', null).order('erstellt_am');
    const dateien = (d || []).map((z) => ({ name: z.name, art: z.art, pfad: z.storage_pfad }));

    let html = e.sicherheit_html || '';
    const imText = [...html.matchAll(/data-pfad="([^"]+)"/g)].map((m) => m[1]);
    const pfade = [...new Set([e.titelfoto_pfad, ...imText, ...dateien.map((z) => z.pfad)].filter(Boolean))] as string[];
    const url: Record<string, string> = {};
    if (pfade.length) {
      const { data: s } = await sb.storage.from(BUCKET).createSignedUrls(pfade, GUELTIG);
      (s || []).forEach((z) => { if (z.signedUrl && z.path) url[z.path] = z.signedUrl; });
    }
    html = html.replace(/<(img|video|source)([^>]*?)data-pfad="([^"]+)"/g, (_m, t, a, p) => `<${t}${a}src="${url[p] || ''}" data-pfad="${p}"`);

    return json({
      titel: e.titel,
      untertitel: e.untertitel || '',
      ufi: e.ufi || '',
      foto: e.titelfoto_pfad ? url[e.titelfoto_pfad] || null : null,
      psa: e.psa || [],
      html,
      dateien: dateien.map((z) => ({ name: z.name, art: z.art, url: url[z.pfad] || null })),
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
