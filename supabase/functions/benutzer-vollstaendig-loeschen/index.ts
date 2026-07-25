// ============================================================================
// Offertentool 2027 - Benutzer vollstaendig loeschen (inkl. Auth-Konto)
//
// Der bisherige "Loeschen"-Button in verwaltung-live-v1.html hat nur die
// Zeile in public.benutzer entfernt - das Supabase-Auth-Konto (E-Mail +
// Passwort) blieb bestehen. Das verhindert u.a., dass eine als Spam erkannte
// Anmeldung die E-Mail-Adresse dauerhaft blockiert: eine echte Neu-
// Registrierung mit derselben Adresse war danach nicht mehr moeglich.
//
// Diese Funktion loescht beides in einem Rutsch, per Admin API mit dem
// Service-Role-Key (der NIE im Browser sichtbar sein darf, deshalb hier
// serverseitig). Nur fuer Admins aufrufbar - die Rolle des Aufrufers wird
// serverseitig geprueft (nicht nur ueber die Client-UI), damit diese
// weitreichende Aktion nicht missbraucht werden kann.
//
// Aufruf vom Client: sb.functions.invoke('benutzer-vollstaendig-loeschen', { body: { id: '<user-uuid>' } })
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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    // Aufrufer anhand des mitgeschickten Auth-Headers ermitteln (wird von
    // sb.functions.invoke() automatisch mit der aktuellen Session mitgesendet)
    // und dessen Rolle serverseitig pruefen - nur Admins duerfen loeschen.
    const authHeader = req.headers.get('Authorization') || '';
    const sbAlsAufrufer = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user } } = await sbAlsAufrufer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);

    const { data: aufrufer } = await sbAlsAufrufer.from('benutzer').select('rolle').eq('id', user.id).maybeSingle();
    if (aufrufer?.rolle !== 'admin') return json({ error: 'Nur Admins duerfen das ausloesen.' }, 403);

    const { id } = await req.json().catch(() => ({ id: '' }));
    if (!id) return json({ error: 'User-ID fehlt.' }, 400);

    // Ab hier mit Service-Role-Key arbeiten (umgeht RLS, kann Auth-Konten
    // loeschen) - bewusst erst NACH der Admin-Pruefung oben.
    const sbAdmin = createClient(supabaseUrl, serviceRoleKey);

    const { error: benutzerError } = await sbAdmin.from('benutzer').delete().eq('id', id);
    if (benutzerError) return json({ error: benutzerError.message }, 500);

    const { error: authError } = await sbAdmin.auth.admin.deleteUser(id);
    if (authError) return json({ error: authError.message }, 500);

    return json({ ok: true });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
