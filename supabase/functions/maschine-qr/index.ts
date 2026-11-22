// ============================================================================
// Maschinen-QR (ohne Anmeldung): knechtgarten.com/m/<code> → /maschine-qr.html?c=<code>
// Der Code steht auf dem Kleber (16 Zufallszeichen). Seit 2026-11-22 ein Kleber pro Stück mit wissen_exemplar.qr_verw
// (Handy-Seite zeigt eine Auswahl); alte Sicherheits-Kleber (qr_sicher) öffnen direkt die Sicherheit.
// Gibt nur diese eine Maschine heraus: Name, Nummer, Foto und beide Teile
//   sicherheit → Schutzausrüstung, Verhaltensregeln, Sicherheitsdatenblätter
//   anleitung  → Anwendung (Kurzanleitung)
// Keine Preise, Notizen, Service oder andere Maschinen. Dateien als kurz gültige signierte Links.
// Aufruf: POST { code }
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

    const { data: x } = await sb.from('wissen_exemplar').select('id,eintrag_id,nummer,qr_sicher,qr_verw')
      .or(`qr_sicher.eq.${c},qr_verw.eq.${c}`).is('archiviert_am', null).maybeSingle();
    if (!x) return json({ error: 'ungueltig' }, 404);
    const art = x.qr_sicher === c ? 'sicherheit' : 'verwendung';

    const { data: e } = await sb.from('wissen_eintrag').select('titel,titelfoto_pfad,psa,sicherheit_html,anwendung_html')
      .eq('id', x.eintrag_id).is('archiviert_am', null).maybeSingle();
    if (!e) return json({ error: 'ungueltig' }, 404);

    let html = e.sicherheit_html || '', anleitung = e.anwendung_html || '';
    const { data: d } = await sb.from('wissen_datei').select('name,art,storage_pfad')
      .eq('eintrag_id', x.eintrag_id).in('bereich', ['sdb', 'sicherheit']).is('exemplar_id', null).order('erstellt_am');   // Datenblatt + Merkblätter
    const dateien = (d || []).map((z) => ({ name: z.name, art: z.art, pfad: z.storage_pfad }));

    // alle Pfade auf einmal signieren: Titelfoto, Medien im Text (data-pfad), Datenblätter
    const imText = [...(html + anleitung).matchAll(/data-pfad="([^"]+)"/g)].map((m) => m[1]);
    const pfade = [...new Set([e.titelfoto_pfad, ...imText, ...dateien.map((z) => z.pfad)].filter(Boolean))] as string[];
    const url: Record<string, string> = {};
    if (pfade.length) {
      const { data: s } = await sb.storage.from(BUCKET).createSignedUrls(pfade, GUELTIG);
      (s || []).forEach((z) => { if (z.signedUrl && z.path) url[z.path] = z.signedUrl; });
    }
    const mitUrl = (h: string) => h.replace(/<(img|video|source)([^>]*?)data-pfad="([^"]+)"/g, (_m, t, a, p) => `<${t}${a}src="${url[p] || ''}" data-pfad="${p}"`);
    html = mitUrl(html); anleitung = mitUrl(anleitung);

    return json({
      art,   // sicherheit = alter Sicherheits-Kleber (direkt), verwendung = Kleber pro Stück (Auswahl)
      titel: e.titel,
      nummer: x.nummer || '',
      foto: e.titelfoto_pfad ? url[e.titelfoto_pfad] || null : null,
      psa: e.psa || [],
      html,        // Sicherheit
      anleitung,
      dateien: dateien.map((z) => ({ name: z.name, art: z.art, url: url[z.pfad] || null })),
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
