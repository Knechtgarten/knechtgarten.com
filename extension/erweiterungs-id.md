# Feste Erweiterungs-ID für Dokumenten-Suche

Erzeugt am 2026-09-27, damit die Chrome-Erweiterung immer dieselbe ID hat,
egal ob sie unverpackt geladen oder neu gepackt wird - notwendig, damit die
OAuth-Redirect-URI in Google Cloud dauerhaft gültig bleibt.

**Extension-ID:** `kibnndocifphcjoopimhcobiiekbpfof`

**OAuth-Redirect-URI (in Google Cloud eintragen):**
`https://kibnndocifphcjoopimhcobiiekbpfof.chromiumapp.org/`

**`key`-Feld für `manifest.json`** (öffentlicher Schlüssel, unbedenklich, kein Geheimnis):

```
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoSTuSrUzEdhJ29PZMZUwcgvi7fiaaKo80FfKgf7y+Eoq1uiw4dcAjSFeh5iNm9tmLd7+CsSeXQu06OSLThRDT7rIneoWmsBxtACm9RxHmrH6vJCMFy12bZpXyfyg5vanSe3S0Sj049UCBPHsbzX+LyXaoX7bIE/e/rd7L7v/z2ym5D/pg6Lj0J3RkdrqfDNLZspTgAyb2nj3GELrI+XIaVaNU2hFF6t4WEGH+AZ83dTnjgpaDIvXUkCubrDwTwtNjcpi0Jvoo3Y7nkZLfiEcgeZtAGX/hejjQ3vS4rj6FtVDiJQGGRl2ERg8G1pABtfRSM++k5aQpKMli66wDtTjPQIDAQAB
```

**Zugehöriger privater Schlüssel:** liegt lokal als `signing-key-PRIVAT-nicht-teilen.pem`
in diesem Ordner, ist per `.gitignore` von Git ausgeschlossen (wird NIE committet/gepusht).
Wird nur gebraucht, falls die Erweiterung irgendwann manuell zu einer signierten
`.crx`-Datei gepackt werden soll - für unverpacktes Laden oder Hochladen in den
Chrome Web Store reicht der öffentliche Schlüssel oben in `manifest.json`.
