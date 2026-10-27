# Knechtgarten-Tools – gemeinsame Regeln

Alle Tools liegen als einzelne HTML-Dateien in `app/` (Supabase, Deploy über GitHub auf Hostinger).
Vorlage für Aussehen und Bedienung ist das **Offerten-Tool** (Tool A–D, v. a. `app/tool-c-live-v1.html`).
Jedes neue Tool übernimmt diesen Stil – nichts neu erfinden.

## Pflicht in jeder Seite (`<head>`, direkt nach `<meta charset>`)
```html
<script src="/kg-pw-schutz.js?v=5"></script>
<script src="/kg-stil.js?v=2"></script>
```
- `kg-pw-schutz.js`: hält Passwort-Manager (Dashlane …) von allen Feldern ausser dem Login fern.
- `kg-stil.js`: gemeinsame Icons und Knopfstil (siehe unten).

## Icons
- Knopf-Icons (Stift, Abfalleimer, Kopieren, Foto, Schloss, Schliessen, Häkchen, Hochladen, Auge, Notiz, Zahnrad …)
  kommen **immer aus `app/kg-stil.js`** (`KG.pfade`, `KG.icon('edit', 14)`). Nie ein eigenes, ähnliches Icon zeichnen.
- Fehlt ein Knopf-Icon, wird es in `kg-stil.js` ergänzt (Form aus dem Offerten-Tool, sonst neu im gleichen Stil) und von dort genommen.
- Tools mit eigener Icon-Liste: Sprite `<symbol id="i-…">` wird von `kg-stil.js` automatisch umgestellt;
  ein JS-Objekt mit Pfaden direkt danach mit `KG.uebernehmen(LISTE)` angleichen.
- Stil: Linien-Icons, 24x24, Strich 1.5px, keine Füllung, Farbe über `currentColor`. Keine Emoji als Icons.
- Überschrift-Icons (z. B. bei aufklappbaren Abschnitten) dürfen eigene sein.

## Knöpfe
- Runder Icon-Knopf: Klasse `kg-ibtn` (24px, Rand `--line`, weiss, Icon grau). Löschen: `kg-ibtn danger` (Hover rot).
  Mehrere Knöpfe einer Zeile rechts nebeneinander, Löschen immer mit Abfalleimer und Sicherheitsfrage.
- Text-Knöpfe wie im Offerten-Tool: `btn btn-primary` (dunkelblau), `btn btn-ghost` (weiss mit Rand).

## Farben
Knechtgarten-Farbkonzept (Skill «knechtgarten-farbkonzept»): `#323E4E` Hauptfarbe, `#F5F7F9` Hintergrund,
`#8B9097` grau, Akzente sparsam `#D6E7F4` (hellblau) und `#D1DB5F` (grün).

## Sprache
Deutsch (Schweiz, ss statt ß), kurze, klare Beschriftungen, Du-Form.
