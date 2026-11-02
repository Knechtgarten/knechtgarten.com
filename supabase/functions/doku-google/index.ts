// ============================================================================
// Doku-Tools: Google-Verbindung für die Drive-Ablage.
// Der Browser holt per Google-Popup (GIS Code-Client, redirect 'postmessage')
// einen einmaligen Code; hier wird er gegen Tokens getauscht. Das Refresh-
// Token bleibt serverseitig in google_verbindung (kein Zugriff vom Browser),
// der Browser bekommt nur kurzlebige Access-Tokens.
// Aktionen: { aktion: 'tauschen', code } | { aktion: 'token' } | { aktion: 'trennen' }
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

// gleiche öffentliche Client-ID wie die Dokumentensuche (Secret nur serverseitig)
const CLIENT_ID = '689526517764-f2727pi1nglt5lkbttec3ssjqkgl47k5.apps.googleusercontent.com';

async function google(params: Record<string, string>) {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data?.error_description || data?.error || `Google-Fehler (${res.status})`);
  return data;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const nutzer = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    });
    const { data: { user } } = await nutzer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const secret = Deno.env.get('GOOGLE_CLIENT_SECRET');
    if (!secret) return json({ error: 'GOOGLE_CLIENT_SECRET ist serverseitig nicht gesetzt.' }, 500);
    const { aktion, code } = await req.json();

    if (aktion === 'tauschen') {
      if (!code) return json({ error: 'code fehlt.' }, 400);
      const t = await google({ code, client_id: CLIENT_ID, client_secret: secret, redirect_uri: 'postmessage', grant_type: 'authorization_code' });
      if (t.refresh_token) {
        const { error } = await admin.from('google_verbindung').upsert({
          benutzer_id: user.id, refresh_token: t.refresh_token, scope: t.scope ?? null, aktualisiert_am: new Date().toISOString(),
        });
        if (error) return json({ error: error.message }, 500);
      }
      return json({ accessToken: t.access_token, expiresIn: t.expires_in });
    }

    if (aktion === 'token') {
      const { data } = await admin.from('google_verbindung').select('refresh_token').eq('benutzer_id', user.id).maybeSingle();
      if (!data) return json({ verbunden: false });
      try {
        const t = await google({ refresh_token: data.refresh_token, client_id: CLIENT_ID, client_secret: secret, grant_type: 'refresh_token' });
        return json({ verbunden: true, accessToken: t.access_token, expiresIn: t.expires_in });
      } catch (_e) {
        // Zugriff bei Google widerrufen oder abgelaufen: neu verbinden lassen
        await admin.from('google_verbindung').delete().eq('benutzer_id', user.id);
        return json({ verbunden: false });
      }
    }

    if (aktion === 'trennen') {
      const { data } = await admin.from('google_verbindung').select('refresh_token').eq('benutzer_id', user.id).maybeSingle();
      if (data) await fetch('https://oauth2.googleapis.com/revoke?token=' + encodeURIComponent(data.refresh_token), { method: 'POST' }).catch(() => {});
      await admin.from('google_verbindung').delete().eq('benutzer_id', user.id);
      return json({ verbunden: false });
    }

    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (e) {
    return json({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
