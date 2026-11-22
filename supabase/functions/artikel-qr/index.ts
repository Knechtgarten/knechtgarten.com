// ============================================================================
// Artikel-QR (ohne Anmeldung): knechtgarten.com/a/<code> → /artikel-qr.html?c=<code>
// Der Code steht auf dem Kleber im Lager (artikel.qr_code, 16 Zufallszeichen). Gibt nur diesen Artikel heraus:
// Bezeichnung, Nummern, Einheit, Lieferant, Foto und – falls mit einem Produkt im Nachschlagewerk verknüpft, das ein
// Sicherheitsdatenblatt hat – den Link zur Datenblatt-Seite /s/<sdb_code> (Code wird bei Bedarf erzeugt).
// Keine Preise. Aufruf: POST { code }
// ============================================================================
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' };
const json = (b: unknown, s = 200) => new Response(JSON.stringify(b), { status: s, headers: { ...cors, 'Content-Type': 'application/json' } });
const zufall = () => { const z = 'abcdefghjkmnpqrstuvwxyz23456789', a = crypto.getRandomValues(new Uint8Array(16)); return [...a].map((b) => z[b % z.length]).join(''); };

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const { code } = await req.json().catch(() => ({}));
    const c = String(code || '').toLowerCase();
    if (!/^[a-z0-9]{12,40}$/.test(c)) return json({ error: 'ungueltig' }, 404);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const { data: a } = await sb.from('artikel').select('bezeichnung,artikelnummer_lieferant,artikelnummer_knecht,einheit,foto_url,lieferant_id,wissen_eintrag_id')
      .eq('qr_code', c).maybeSingle();
    if (!a) return json({ error: 'ungueltig' }, 404);

    let lieferant = '';
    if (a.lieferant_id) { const { data: l } = await sb.from('lieferant').select('firma,name').eq('id', a.lieferant_id).maybeSingle(); lieferant = l?.firma || l?.name || ''; }

    let sdb: { titel: string; url: string } | null = null;
    if (a.wissen_eintrag_id) {
      const { data: e } = await sb.from('wissen_eintrag').select('id,titel,sdb_code').eq('id', a.wissen_eintrag_id).is('archiviert_am', null).maybeSingle();
      const { count } = e ? await sb.from('wissen_datei').select('id', { count: 'exact', head: true }).eq('eintrag_id', e.id).eq('bereich', 'sdb') : { count: 0 };
      if (e && count) {
        let sc = e.sdb_code;
        if (!sc) { sc = zufall(); await sb.from('wissen_eintrag').update({ sdb_code: sc }).eq('id', e.id); }
        sdb = { titel: e.titel, url: 'https://knechtgarten.com/s/' + sc };
      }
    }

    return json({
      bezeichnung: a.bezeichnung || '',
      nummer: a.artikelnummer_lieferant || a.artikelnummer_knecht || '',
      einheit: a.einheit || '',
      lieferant,
      foto: /^https:\/\//.test(a.foto_url || '') ? a.foto_url : null,
      sdb,
    });
  } catch (err) {
    return json({ error: String(err) }, 500);
  }
});
