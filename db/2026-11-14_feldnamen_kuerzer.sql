-- Konfigurator-Balken einzeilig: Auswahlfeld-Namen kürzen (nur Anzeige im Konfigurator)
update public.auswahlfeld set name = 'Verrohrung' where name = 'Verrohrung Übergabepunkt-Technikstandort';
update public.auswahlfeld set name = 'Aufbereitung mit Filtersteuerung' where name = 'Wasseraufbereitung automatisch mit Filtersteuerung';
update public.auswahlfeld set name = 'Aufbereitung ohne Filtersteuerung' where name = 'Wasseraufbereitung automatisch ohne Filtersteuerung';
