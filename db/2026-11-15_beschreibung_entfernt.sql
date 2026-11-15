-- Feld «Beschreibung» im Offerten-Blatt entfernt. Alle 5 Einträge waren automatisch erzeugt (beschreibung_manuell=false).
-- Formel-Offerte 2026-010104: Teilschritt-Text in die Hinweise übernehmen, damit er im Easybill-Export bleibt.
update public.offerte
   set optionen_text_liste = '- Hochbeete und Tröge aus der Tabelle «Trog, Hochbeet» befüllen' || coalesce(E'\n' || nullif(trim(optionen_text_liste), ''), '')
 where offertnummer = '2026-010104'
   and coalesce(optionen_text_liste, '') not like '%Hochbeete und Tröge aus der Tabelle%';
update public.offerte set beschreibung_block = null where beschreibung_block is not null;
