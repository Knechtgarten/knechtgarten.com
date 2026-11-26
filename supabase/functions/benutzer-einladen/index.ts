// ============================================================================
// Knechtgarten-Tools - Benutzer einladen / temporäre Benutzer / persönlicher Link
//
// Selbstregistrierung ist abgeschaltet (Trigger handle_new_auth_user verlangt
// app_metadata.eingeladen = true). Neue Logins entstehen nur noch hier:
//
//   { aktion: 'einladen', id }            Person (Platzhalter mit E-Mail) bekommt ein Login:
//                                          Auth-Konto anlegen (E-Mail gilt als bestätigt) und
//                                          einen Link zum Passwort-Festlegen zurückgeben.
//                                          Hat die Person schon ein Login: nur neuer Link.
//   { aktion: 'temporaer', name, telefon } Temporären anlegen: Auth-Konto mit Ersatz-Adresse,
//                                          Rechte-Gruppe «Temporär», Planer-Zeile im Block
//                                          «Schnupper / Temporär», persönlicher Link.
//   { aktion: 'link-neu', id }             Temporär: neuer Link, der alte gilt sofort nicht mehr.
//   { aktion: 'sperren', id }              Temporär: Link sperren.
//   { aktion: 'login-einrichten', id, email }  Login für eine Person (E-Mail = Benutzername):
//                                          Platzhalter bekommt ein Konto mit GLEICHER ID (Verknüpfungen
//                                          bleiben), dazu ein Einrichtungs-Link. Hat sie schon ein Login:
//                                          nur neuer Einrichtungs-Link (Passwort vergessen).
//   { aktion: 'mitarbeiter', name, email, gruppe_id }  Neue Person mit Login + Einrichtungs-Link.
//   Einrichtungs-Link = einrichten.html#t=…, 7 Tage gültig, einmal; die Person wählt ihr Passwort selbst.
//   Büro-Team darf keine Admins anfassen und niemanden zum Admin machen.
//
// Der Link wird NICHT per Mail verschickt, sondern zurückgegeben – das Büro schickt ihn
// selbst (kopieren, Mail, WhatsApp). Nur Admins und Büro-Team dürfen das auslösen.
// Aufruf: sb.functions.invoke('benutzer-einladen', { body: { aktion, ..., basis: location.origin } })
// ============================================================================

import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

const zufall = (n = 32) => { const a = new Uint8Array(n); crypto.getRandomValues(a); return btoa(String.fromCharCode(...a)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, ''); };
const sha256 = async (s: string) => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s)))).map(b => b.toString(16).padStart(2, '0')).join('');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const url = Deno.env.get('SUPABASE_URL')!, anon = Deno.env.get('SUPABASE_ANON_KEY')!, service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const sbAufrufer = createClient(url, anon, { global: { headers: { Authorization: req.headers.get('Authorization') || '' } } });
    const { data: { user } } = await sbAufrufer.auth.getUser();
    if (!user) return json({ error: 'Nicht angemeldet.' }, 401);
    const { data: ich } = await sbAufrufer.from('benutzer').select('rolle').eq('id', user.id).maybeSingle();
    if (!['admin', 'buero_team'].includes(ich?.rolle || '')) return json({ error: 'Nur Admins und Büro-Team dürfen Benutzer einladen.' }, 403);

    const body = await req.json().catch(() => ({}));
    const basis = String(body.basis || 'https://knechtgarten.com').replace(/\/+$/, '');
    const sb = createClient(url, service); // ab hier mit Service-Role (erst nach der Rollenprüfung)

    // Persönlichen Link (Temporär) neu erzeugen: nur der Hash wird gespeichert
    const neuerZugang = async (benutzerId: string) => {
      const token = zufall();
      const { error } = await sb.from('benutzer_zugang').upsert({ benutzer_id: benutzerId, token_hash: await sha256(token), gesperrt: false, erstellt_am: new Date().toISOString() });
      if (error) throw new Error(error.message);
      return `${basis}/zugang.html#t=${token}`;
    };

    // Einrichtungs-Link (Passwort selbst wählen): 7 Tage, einmal, nur Hash gespeichert
    const einrichtungsLink = async (benutzerId: string) => {
      const token = zufall();
      const { error } = await sb.from('benutzer_einrichtung').upsert({ benutzer_id: benutzerId, token_hash: await sha256(token), gueltig_bis: new Date(Date.now() + 7 * 86400000).toISOString(), erstellt_am: new Date().toISOString() });
      if (error) throw new Error(error.message);
      return `${basis}/einrichten.html#t=${token}`;
    };
    const istAdmin = ich?.rolle === 'admin';
    const adminGruppe = async (gid: string | null) => !!gid && !!(await sb.from('recht_gruppe').select('ist_admin').eq('id', gid).maybeSingle()).data?.ist_admin;
    const mailOk = (m: string) => /^[^\s@]+@[^\s@]+\.[a-z]{2,}$/i.test(m);
    const planerZeile = async (id: string, name: string) => {
      const { data: pp } = await sb.from('planer_person').select('id').eq('benutzer_id', id).limit(1);
      if (pp?.length) return;
      const { data: g } = await sb.from('planer_gruppe').select('id').eq('name', 'Neu').maybeSingle();
      if (g) await sb.from('planer_person').insert({ gruppe_id: g.id, name, benutzer_id: id, sortierung: 1, aktiv: true });
    };
    const mailFrei = async (email: string, ausser: string | null) => {
      const { data } = await sb.from('benutzer').select('id').ilike('email', email);
      return !(data || []).some(x => x.id !== ausser);
    };

    if (body.aktion === 'login-einrichten') {
      const { data: b } = await sb.from('benutzer').select('id,email,anzeigename,rolle,recht_gruppe_id,ist_platzhalter,ist_temporaer').eq('id', body.id).maybeSingle();
      if (!b) return json({ error: 'Person nicht gefunden.' }, 404);
      if (b.ist_temporaer) return json({ error: 'Temporäre melden sich über ihren persönlichen Link an.' }, 400);
      if (!istAdmin && (b.rolle === 'admin' || await adminGruppe(b.recht_gruppe_id))) return json({ error: 'Administratoren kann nur ein Admin ändern.' }, 403);
      if (b.ist_platzhalter) {
        const email = String(body.email || b.email || '').trim().toLowerCase();
        if (!mailOk(email)) return json({ error: 'Bitte eine gültige E-Mail-Adresse eingeben (sie ist der Benutzername).' }, 400);
        if (!await mailFrei(email, b.id)) return json({ error: 'Diese E-Mail hat schon jemand anderes.' }, 400);
        await sb.from('benutzer').update({ email }).eq('id', b.id);
        await sb.from('benutzer_einladung').upsert({ email, erstellt_am: new Date().toISOString() }); // Freigabe für den Trigger
        const { error } = await sb.auth.admin.createUser({ id: b.id, email, email_confirm: true, password: zufall(24), app_metadata: { eingeladen: true } });
        if (error) return json({ error: /already|registered|exists/i.test(error.message) ? 'Für diese E-Mail gibt es schon ein Login.' : error.message }, 400);
        await planerZeile(b.id, b.anzeigename || email);
      }
      return json({ ok: true, id: b.id, link: await einrichtungsLink(b.id) });
    }

    if (body.aktion === 'mitarbeiter') {
      const name = String(body.name || '').trim(), email = String(body.email || '').trim().toLowerCase(), gid = body.gruppe_id || null;
      if (!name) return json({ error: 'Name fehlt.' }, 400);
      if (!mailOk(email)) return json({ error: 'Bitte eine gültige E-Mail-Adresse eingeben (sie ist der Benutzername).' }, 400);
      if (!gid) return json({ error: 'Bitte eine Gruppe wählen.' }, 400);
      if (!istAdmin && await adminGruppe(gid)) return json({ error: 'Die Gruppe Administrator kann nur ein Admin vergeben.' }, 403);
      if (!await mailFrei(email, null)) return json({ error: 'Diese E-Mail hat schon jemand.' }, 400);
      await sb.from('benutzer_einladung').upsert({ email, erstellt_am: new Date().toISOString() });
      const { data: au, error } = await sb.auth.admin.createUser({ email, email_confirm: true, password: zufall(24), app_metadata: { eingeladen: true } });
      if (error || !au?.user) return json({ error: /already|registered|exists/i.test(error?.message || '') ? 'Für diese E-Mail gibt es schon ein Login.' : (error?.message || 'Konto nicht angelegt.') }, 400);
      const id = au.user.id;
      const { error: be } = await sb.from('benutzer').update({ anzeigename: name, recht_gruppe_id: gid, aktiv: true }).eq('id', id);
      if (be) return json({ error: be.message }, 500);
      await planerZeile(id, name);
      return json({ ok: true, id, link: await einrichtungsLink(id) });
    }

    if (body.aktion === 'einladen') {
      const { data: b } = await sb.from('benutzer').select('id,email,anzeigename,ist_platzhalter').eq('id', body.id).maybeSingle();
      if (!b) return json({ error: 'Person nicht gefunden.' }, 404);
      const email = String(b.email || '').trim().toLowerCase();
      if (!email || !email.includes('@')) return json({ error: 'Bitte zuerst eine E-Mail-Adresse erfassen.' }, 400);
      let neuId = b.id;
      if (b.ist_platzhalter) { // Auth-Konto anlegen – der Trigger übernimmt den Platzhalter (Rolle, Gruppe, Angaben bleiben)
        await sb.from('benutzer_einladung').upsert({ email, erstellt_am: new Date().toISOString() }); // Freigabe für den Trigger
        const { data: au, error } = await sb.auth.admin.createUser({ email, email_confirm: true, app_metadata: { eingeladen: true } });
        if (error && !/already|registered|exists/i.test(error.message)) return json({ error: error.message }, 500);
        if (au?.user) neuId = au.user.id;
      }
      const { data: link, error: le } = await sb.auth.admin.generateLink({ type: 'recovery', email, options: { redirectTo: `${basis}/tool-start-live-v1.html` } });
      if (le) return json({ error: le.message }, 500);
      // Planer-Zeile im Block «Neu», falls die Person noch keine hat
      const { data: pp } = await sb.from('planer_person').select('id').eq('benutzer_id', neuId).limit(1);
      if (!pp?.length) {
        const { data: g } = await sb.from('planer_gruppe').select('id').eq('name', 'Neu').maybeSingle();
        if (g) await sb.from('planer_person').insert({ gruppe_id: g.id, name: b.anzeigename || email, benutzer_id: neuId, sortierung: 1, aktiv: true });
      }
      return json({ ok: true, id: neuId, link: link.properties.action_link });
    }

    if (body.aktion === 'temporaer') {
      const name = String(body.name || '').trim(); if (!name) return json({ error: 'Name fehlt.' }, 400);
      const email = `temp-${crypto.randomUUID().slice(0, 12)}@temp.knechtgarten.ch`;
      await sb.from('benutzer_einladung').upsert({ email, erstellt_am: new Date().toISOString() }); // Freigabe für den Trigger
      const { data: au, error } = await sb.auth.admin.createUser({ email, email_confirm: true, password: zufall(24), app_metadata: { eingeladen: true, temporaer: true } });
      if (error || !au?.user) return json({ error: error?.message || 'Konto nicht angelegt.' }, 500);
      const id = au.user.id;
      const { data: rg } = await sb.from('recht_gruppe').select('id').eq('schluessel', 'temp').maybeSingle();
      const { error: be } = await sb.from('benutzer').update({ anzeigename: name, telefon: String(body.telefon || '').trim() || null, rolle: 'mitarbeitende', recht_gruppe_id: rg?.id || null, ist_temporaer: true, aktiv: true }).eq('id', id);
      if (be) return json({ error: be.message }, 500);
      const { data: g } = await sb.from('planer_gruppe').select('id').ilike('name', 'schnupper%').maybeSingle();
      if (g) await sb.from('planer_person').insert({ gruppe_id: g.id, name, benutzer_id: id, sortierung: 500, aktiv: true });
      return json({ ok: true, id, link: await neuerZugang(id) });
    }

    if (body.aktion === 'link-neu' || body.aktion === 'sperren') {
      const { data: b } = await sb.from('benutzer').select('id,ist_temporaer').eq('id', body.id).maybeSingle();
      if (!b?.ist_temporaer) return json({ error: 'Nur bei temporären Benutzern.' }, 400);
      if (body.aktion === 'sperren') { await sb.from('benutzer_zugang').update({ gesperrt: true }).eq('benutzer_id', b.id); return json({ ok: true }); }
      return json({ ok: true, link: await neuerZugang(b.id) });
    }

    return json({ error: 'Unbekannte Aktion.' }, 400);
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
