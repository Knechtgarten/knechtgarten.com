/* kgPasswortManagerSchutz – gemeinsam für ALLE Tools.
   Einbinden ganz oben im <head>, vor allen anderen Skripten:
     <script src="/kg-pw-schutz.js?v=1"></script>

   Passwort-Manager (Dashlane, LastPass, 1Password, Bitwarden) dürfen nur beim Login
   (.logincard, autocomplete="username" / "current-password") etwas eintragen, sonst nirgends.

   1) HTML, das per innerHTML / outerHTML / insertAdjacentHTML eingesetzt wird, bekommt die
      Abwehr-Merkmale schon im Text. Der Passwort-Manager sieht das Feld so nie «ungeschützt»
      (sein eigener Beobachter läuft sonst vor unserem und hängt sein Symbol an).
   2) Rückfallebene für statisches HTML und createElement: MutationObserver.
   3) Login-Karte wird in ein <form> gepackt (Passwort-Manager erkennen das Login nur so zuverlässig).

   Neue Tools brauchen nichts weiter – nur diese eine Zeile im <head>. */
(function(){
  if(window.kgPwSchutz) return; window.kgPwSchutz = true;
  var AUSNAHMEN = ['username', 'current-password', 'new-password', 'one-time-code'];
  var OHNE_TYP = ['password', 'hidden', 'checkbox', 'radio', 'file', 'button', 'submit', 'reset', 'image', 'range', 'color'];
  var ATTR = [['autocomplete', 'off'], ['data-lpignore', 'true'], ['data-1p-ignore', 'true'], ['data-bwignore', 'true'],
              ['data-dashlane-ignore', 'true'], ['data-form-type', 'other']];

  // 1) Textweg: <input …> / <textarea …> im HTML-Text ergänzen
  var TAG = /<(input|textarea)\b([^>]*)>/gi;
  function ergaenze(html){
    if(typeof html !== 'string' || html.indexOf('<') < 0) return html;
    return html.replace(TAG, function(m, tag, rest){
      var r = rest.toLowerCase();
      if(r.indexOf('data-kg-pw') !== -1) return m;
      var typ = (r.match(/\btype\s*=\s*["']?([a-z-]+)/) || [])[1] || 'text';
      if(tag.toLowerCase() === 'input' && OHNE_TYP.indexOf(typ) !== -1) return m;
      var ac = (r.match(/\bautocomplete\s*=\s*["']?([a-z-]+)/) || [])[1];
      if(ac && AUSNAHMEN.indexOf(ac) !== -1) return m;
      var add = ' data-kg-pw="1"';
      for(var i = 0; i < ATTR.length; i++) if(!new RegExp('(^|\\s)' + ATTR[i][0] + '\\s*=').test(r)) add += ' ' + ATTR[i][0] + '="' + ATTR[i][1] + '"';
      return '<' + tag + add + rest + '>';
    });
  }
  function haken(proto, prop){
    var d = proto && Object.getOwnPropertyDescriptor(proto, prop);
    if(!d || !d.set) return;
    Object.defineProperty(proto, prop, { configurable: true, enumerable: d.enumerable, get: d.get,
      set: function(v){ d.set.call(this, ergaenze(v)); } });
  }
  haken(Element.prototype, 'innerHTML');
  haken(Element.prototype, 'outerHTML');
  if(window.ShadowRoot) haken(ShadowRoot.prototype, 'innerHTML');
  var iah = Element.prototype.insertAdjacentHTML;
  Element.prototype.insertAdjacentHTML = function(pos, html){ return iah.call(this, pos, ergaenze(html)); };

  // 2) Rückfallebene: Felder, die anders entstehen
  function schuetze(el){
    if(!el || el.nodeType !== 1) return;
    var tag = el.tagName;
    if(tag !== 'INPUT' && tag !== 'TEXTAREA') return;
    if(el.getAttribute('data-kg-pw') && el.getAttribute('data-form-type')) return;
    var typ = (el.getAttribute('type') || 'text').toLowerCase();
    if(tag === 'INPUT' && OHNE_TYP.indexOf(typ) !== -1) return;
    if(AUSNAHMEN.indexOf((el.getAttribute('autocomplete') || '').toLowerCase()) !== -1) return;
    if(el.closest && el.closest('.logincard')) return;
    el.setAttribute('data-kg-pw', '1');
    for(var i = 0; i < ATTR.length; i++) el.setAttribute(ATTR[i][0], ATTR[i][1]);
  }
  function alle(root){
    if(!root || root.nodeType !== 1) return;
    schuetze(root);
    var liste = root.querySelectorAll ? root.querySelectorAll('input, textarea') : [];
    for(var i = 0; i < liste.length; i++) schuetze(liste[i]);
  }
  new MutationObserver(function(ms){
    for(var i = 0; i < ms.length; i++) for(var k = 0; k < ms[i].addedNodes.length; k++) alle(ms[i].addedNodes[k]);
  }).observe(document.documentElement, { childList: true, subtree: true });

  // 3) Login-Karte in ein <form> packen, statische Felder schützen
  function start(){
    var karten = document.querySelectorAll('.logincard');
    for(var ki = 0; ki < karten.length; ki++){
      var karte = karten[ki];
      if(!karte.parentNode || karte.closest('form') || !karte.querySelector('input[type="password"]')) continue;
      var f = document.createElement('form');
      f.setAttribute('novalidate', '');
      f.style.display = 'contents';
      f.addEventListener('submit', function(e){ e.preventDefault(); });
      karte.parentNode.insertBefore(f, karte);
      f.appendChild(karte);
    }
    alle(document.documentElement);
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start); else start();
})();
