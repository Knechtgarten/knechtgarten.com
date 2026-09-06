-- ============================================================================
-- Mengenoption (auswahloption.mengenoption) bekommt einen optionalen
-- Standardmenge-Wert: erscheint im Konfigurator (Tool A) bereits
-- vorausgefuellt statt leer/0, bleibt dort aber weiterhin frei aenderbar.
-- Wird nur beim ALLERERSTEN Anzeigen dieser Option in einer Offerte als
-- Vorschlag uebernommen - eine bereits gespeicherte Anzahl (auch 0) wird nie
-- ueberschrieben (siehe renderBereich() in tool-a-live-v1.html).
-- ============================================================================

alter table auswahloption add column mengenoption_standardmenge numeric null;
