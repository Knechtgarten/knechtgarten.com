-- Mail-Assistent: Externe Kontakte bekommen ein Feld fuer den Namen, der bei
-- der Anrede verwendet werden soll (z.B. Vorname bei "Per Du" -> "Hallo
-- Silvio", oder Nachname bei "Per Sie" -> "Guten Tag Herr Grütter") - falls
-- der Name in der eingehenden Mail selbst nicht eindeutig hervorgeht.
alter table mailassistent_externe_kontakte add column if not exists anrede_name text;
