// ============================================================================
// Gemeinsam fuer Seitenpanel (sidepanel.html) und Hintergrund (background.js,
// per importScripts): Google-Token aus chrome.storage.local holen/erneuern und
// die Kuerzel (Kurzinfos aus dem Nachschlagewerk) laden.
//
// Kuerzel: Die Liste [{ kuerzel, wert }] landet in chrome.storage.local unter
// "kuerzelListe" - von dort liest sie kuerzel-content.js auf jeder Seite.
// Die Edge Function gibt sie nur heraus, wenn das Google-Konto zu
// @knechtgarten.ch gehoert (IBAN & Co. sollen nicht oeffentlich abrufbar sein).
// ============================================================================

const EDGE_FUNCTION_URL = 'https://oalapdxinqlnzwxhyuzy.supabase.co/functions/v1/dokumenten-suche';
const SUPABASE_ANON_KEY = 'sb_publishable_DoeD4uEnwemmnFu4AxE9uw_5lmQYc5P';

// Speichert Access-Token + Ablaufzeit, behaelt einen vorhandenen Refresh-Token
// bei, falls die aktuelle Antwort (z.B. eine reine Erneuerung) keinen neuen
// mitliefert - Google gibt den Refresh-Token normalerweise nur beim ersten
// Consent zurueck.
async function speichereToken({ accessToken, expiresIn, refreshToken }) {
  const vorhandenes = (await chrome.storage.local.get('googleToken')).googleToken || {};
  await chrome.storage.local.set({
    googleToken: {
      accessToken,
      ablaufZeit: Date.now() + (Number(expiresIn) || 3600) * 1000,
      refreshToken: refreshToken || vorhandenes.refreshToken || null,
    },
  });
}

async function holeGespeichertenToken() {
  const { googleToken } = await chrome.storage.local.get('googleToken');
  if (!googleToken) return null;
  // 60 Sekunden Puffer vor dem eigentlichen Ablauf.
  if (googleToken.ablaufZeit > Date.now() + 60_000) return googleToken.accessToken;
  if (!googleToken.refreshToken) return null;
  // Access-Token abgelaufen, aber Refresh-Token vorhanden: im Hintergrund
  // erneuern statt die/den Mitarbeitende(n) erneut durch die Google-Anmeldung
  // zu schicken.
  try {
    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      body: JSON.stringify({ oauthAction: 'refresh', refreshToken: googleToken.refreshToken }),
    });
    const data = await res.json();
    if (!res.ok || !data.accessToken) throw new Error(data.error || 'Refresh fehlgeschlagen.');
    await speichereToken({ accessToken: data.accessToken, expiresIn: data.expiresIn, refreshToken: googleToken.refreshToken });
    return data.accessToken;
  } catch (e) {
    console.error('Automatische Token-Erneuerung fehlgeschlagen:', e);
    return null;
  }
}

// Holt die Kuerzel frisch und speichert sie. Bei einem Fehler bleibt die
// zuletzt geladene Liste stehen (Ersetzen soll auch kurz offline gehen),
// nur der Fehler wird unter "kuerzelStand" vermerkt.
async function ladeKuerzel() {
  const token = await holeGespeichertenToken();
  if (!token) {
    await chrome.storage.local.set({ kuerzelStand: { fehler: 'Nicht mit Google verbunden.', zeit: Date.now() } });
    return null;
  }
  try {
    const res = await fetch(EDGE_FUNCTION_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${SUPABASE_ANON_KEY}` },
      body: JSON.stringify({ aktion: 'kurzinfos', googleAccessToken: token }),
    });
    const data = await res.json();
    if (!res.ok || !Array.isArray(data.kuerzel)) throw new Error(data.error || `Fehler ${res.status}`);
    await chrome.storage.local.set({
      kuerzelListe: data.kuerzel,
      kuerzelStand: { fehler: null, zeit: Date.now(), anzahl: data.kuerzel.length },
    });
    return data.kuerzel;
  } catch (e) {
    console.error('Kürzel laden fehlgeschlagen:', e);
    await chrome.storage.local.set({ kuerzelStand: { fehler: String(e.message || e), zeit: Date.now() } });
    return null;
  }
}
