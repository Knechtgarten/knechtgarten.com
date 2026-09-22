-- Margen-Vorschlag (%) bei einer Freitext-Position-Vorlage (Tool B) - dient
-- als vorausgefuellter Vorschlag fuer das "Marge %"-Feld im "Preis
-- zusammenrechnen"-Popup in Tool A, damit eine Fremdleistungsposition ohne
-- eigenen Artikel nicht versehentlich ohne Marge 1:1 weitergegeben wird.
alter table option_freitext_vorlage add column margen_vorschlag_prozent numeric null;
