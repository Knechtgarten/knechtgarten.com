// ============================================================================
// Knechtgarten-Tools - Anmeldung temporärer Benutzer über den persönlichen Link
// + Einrichtungs-Link für Mitarbeitende (aktion info / passwort, einrichten.html)
//
// zugang.html#t=<schlüssel> ruft diese Funktion OHNE Login auf. Sie sucht den Hash
// des Schlüssels in benutzer_zugang (nicht gesperrt, Benutzer aktiv und temporär)
// und gibt einen einmaligen Anmelde-Token zurück; der Browser meldet sich damit an
// (sb.auth.verifyOtp({ type: 'magiclink', token_hash })). Der Link selbst bleibt
// gültig, bis das Büro ihn sperrt oder neu erstellt.
// Aufruf: fetch(SUPABASE_URL/functions/v1/zugang, { body: { token } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
const sha256 = async (s: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))).map(b => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const { token, aktion, passwort } = await req.json().catch(() => ({ token: '' }));
    if (!token || String(token).length < 20) return json({ error: 'Link ungültig.' }, 400);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    // Einrichtungs-Link (einrichten.html): 'info' = Name + E-Mail zeigen, 'passwort' = Passwort setzen (Link danach verbraucht)
    if (aktion === 'info' || aktion === 'passwort') {
      const { data: e } = await sb.from('benutzer_einrichtung').select('benutzer_id,gueltig_bis').eq('token_hash', await sha256(String(token))).maybeSingle();
      if (!e) return json({ error: 'Dieser Link wurde schon benutzt oder gilt nicht mehr. Bitte im Büro einen neuen verlangen.' }, 403);
      if (new Date(e.gueltig_bis).getTime() < Date.now()) return json({ error: 'Dieser Link ist abgelaufen. Bitte im Büro einen neuen verlangen.' }, 403);
      const { data: b } = await sb.from('benutzer').select('email,anzeigename,aktiv').eq('id', e.benutzer_id).maybeSingle();
      if (!b || b.aktiv === false) return json({ error: 'Dieser Zugang ist gesperrt. Bitte im Büro melden.' }, 403);
      if (aktion === 'info') return json({ ok: true, name: b.anzeigename || '', email: b.email });
      const pw = String(passwort || '');
      if (pw.length < 8) return json({ error: 'Das Passwort braucht mindestens 8 Zeichen.' }, 400);
      const { error } = await sb.auth.admin.updateUserById(e.benutzer_id, { password: pw });
      if (error) return json({ error: /weak|pwned|leaked/i.test(error.message) ? 'Dieses Passwort ist zu einfach oder bekannt. Bitte ein anderes wählen.' : error.message }, 400);
      await sb.from('benutzer_einrichtung').delete().eq('benutzer_id', e.benutzer_id);
      return json({ ok: true, email: b.email });
    }
    const { data: z } = await sb.from('benutzer_zugang').select('benutzer_id,gesperrt').eq('token_hash', await sha256(String(token))).maybeSingle();
    if (!z || z.gesperrt) return json({ error: 'Dieser Link gilt nicht mehr. Bitte im Büro einen neuen verlangen.' }, 403);
    const { data: b } = await sb.from('benutzer').select('email,aktiv,ist_temporaer').eq('id', z.benutzer_id).maybeSingle();
    if (!b || b.aktiv === false || !b.ist_temporaer) return json({ error: 'Dieser Zugang ist gesperrt. Bitte im Büro melden.' }, 403);
    const { data: link, error } = await sb.auth.admin.generateLink({ type: 'magiclink', email: b.email });
    if (error) return json({ error: error.message }, 500);
    return json({ ok: true, token_hash: link.properties.hashed_token });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
