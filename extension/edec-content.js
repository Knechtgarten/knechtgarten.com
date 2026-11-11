// ============================================================================
// e-dec-web (BAZG, Zugangscode-Formular): vom Knopf «Verfügung anfordern» in
// PEAX geöffnet. Füllt Zollanmeldungsnummer, Zugangscode und E-Mail
// zoll@knechtgarten.ch aus und setzt den Cursor ins Captcha-Feld.
// Abtippen des Captchas und «Absenden» bleiben beim Menschen.
// Der Auftrag (chrome.storage.local «edecAuftrag») gilt 10 Minuten und nur einmal.
// ============================================================================
(function () {
  const ADRESSE = 'zoll@knechtgarten.ch';

  function setzen(id, wert) {
    const el = document.getElementById(id);
    if (!el) return false;
    el.focus();
    el.value = wert;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }

  function hinweis(text) {
    const el = document.createElement('div');
    el.textContent = text;
    el.style.cssText = 'position:fixed;right:20px;bottom:20px;z-index:2147483647;max-width:340px;padding:10px 14px;border-radius:10px;font:13px/1.4 -apple-system,Segoe UI,Arial,sans-serif;color:#fff;background:#323E4E;box-shadow:0 6px 20px rgba(0,0,0,.2);';
    document.body.appendChild(el); setTimeout(() => el.remove(), 12000);
  }

  chrome.storage.local.get('edecAuftrag', ({ edecAuftrag: a }) => {
    if (!a || Date.now() - (a.zeit || 0) > 10 * 60000) return;
    let versuche = 0;
    const t = setInterval(() => {
      versuche++;
      if (!document.getElementById('InputForm:ZaNr')) { if (versuche > 40) clearInterval(t); return; }
      clearInterval(t);
      setzen('InputForm:ZaNr', a.zanr);
      setzen('InputForm:Zugangscode', a.code);
      setzen('InputForm:Email', ADRESSE);
      document.getElementById('InputForm:CaptchaInput')?.focus();
      chrome.storage.local.remove('edecAuftrag');
      hinweis('Knechtgarten: Nummer, Zugangscode und zoll@knechtgarten.ch sind ausgefüllt. Bitte nur noch den Sicherheitscode abtippen und «Absenden».');
    }, 250);
  });
})();
