# Knechtgarten-Tools – gemeinsame Regeln

Alle Tools liegen als einzelne HTML-Dateien in `app/` (Supabase, Deploy über GitHub auf Hostinger).
Vorlage für Aussehen und Bedienung ist das **Offerten-Tool** (Tool A–D, v. a. `app/tool-c-live-v1.html`).
Jedes neue Tool übernimmt diesen Stil – nichts neu erfinden.

## Pflicht in jeder Seite (`<head>`, direkt nach `<meta charset>`)
```html
<script src="/kg-pw-schutz.js?v=5"></script>
<script src="/kg-stil.js?v=67"></script>
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

## Gemeinsame Leiste & Tool-Icons
- `kg-stil.js` ersetzt in jedem `<header class="app">` «Zurück» + Titel durch den Tool-Umschalter (Icon + Name + Menü aller Tools).
  Neue Seite eines Tools → Dateiname in `TOOLS[].seiten` in `kg-stil.js` eintragen. Neues Haupttool → Eintrag in `TOOLS` + Icon in `TI`.
- Aufbau der dunklen Leiste (macht `kg-stil.js` automatisch): [Tool-Umschalter][Reiter des Tools …][Tool-Icons] … [Hilfe ?][Personen-Menü].
  Reiter = Hauptseiten des Tools, entweder `<nav>` im Kopf (Offertentool) oder `<nav class="subnav">` direkt nach dem Header (wird in die Leiste verschoben, `#subnav` bleibt erhalten).
  Kein eigenes Zahnrad, kein eigener Abmelden-Knopf: persönliche Einstellungen eines Tools hängen am Knopf `[data-seto]` (erscheint als «Meine Einstellungen» im Personen-Menü),
  Tool-Konfiguration ist ein normaler Reiter (z. B. «Vorlagen & Berechnung»), Firmenweites gehört in die Verwaltung.
  Weisse zweite Zeile nur für Werkzeuge der aktuellen Seite (Filter, Ansicht, Aktionen), nie für Navigation.
- Tool-Icons nur über `KG.toolIcon('pend', 26)`; Farbe = Palette Stufe 2. Mailassistent/Dokumentensuche haben kein eigenes Tool-Icon.

## Farben
Knechtgarten-Farbkonzept (Skill «knechtgarten-farbkonzept»): `#323E4E` Hauptfarbe, `#F5F7F9` Hintergrund,
`#8B9097` grau, Akzente sparsam `#D6E7F4` (hellblau) und `#D1DB5F` (grün). Im Code: `KG.grund`.
Für alles, was unterscheidbar sein muss (Tool-Icons, Pendenzen-Listen, Personen im Planer, Kategorien): nur `KG.palette`
(10 Familien × 5 Stufen), Planer-Teams aus `KG.planerTeams`, Schrift auf Farbe mit `KG.textAuf(hex)`. Keine eigenen Hex-Farben erfinden.

## Sprache
Deutsch (Schweiz, ss statt ß), kurze, klare Beschriftungen, Du-Form.
