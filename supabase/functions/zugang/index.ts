// ============================================================================
// Knechtgarten-Tools - Anmeldung temporärer Benutzer über den persönlichen Link
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
    const { token } = await req.json().catch(() => ({ token: '' }));
    if (!token || String(token).length < 20) return json({ error: 'Link ungültig.' }, 400);
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
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
