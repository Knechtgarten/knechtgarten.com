-- Pooloptionen › Poolboden: «Boden auf PP Becken m2» und «Boden auf Beton/Folie m2» waren Mengen-Optionen (m² zusätzlich eingeben) –
-- die Zeilen rechnen aber schon mit «Fläche Poolboden» (Länge × Breite), dadurch wurde die Fläche doppelt gerechnet. Jetzt normale Optionen.
update auswahloption set mengenoption = false where id in ('bfaca2dd-099b-48ca-929c-649bca157714', 'fefba785-82d0-464c-9706-658e233803a3');
-- Transport Baumaterial (t) aus der Fläche: Fläche Poolboden × 1.2 (20 % Verschnitt wie die Platte) × 0.046 t/m² (Keramikplatte 2 cm), mindestens 2 t
update ressourcenzeile set menge_ausdruck = '{"op": "*", "args": [{"op": "*", "args": [{"id": "d981115b-2905-4e11-9e4a-2cf74bc2389d", "ref": "term"}, {"lit": 1.2}]}, {"lit": 0.046}]}'::jsonb,
  mindestmenge = 2
where id = 'b54b9405-8e8a-4dd1-a98d-0cf5abf3d946';
-- alte Anzahl (m²) in Offerten zurücksetzen – sie wurde zusätzlich zur Fläche multipliziert
update offerte_auswahl set anzahl = 1 where option_id in ('bfaca2dd-099b-48ca-929c-649bca157714', 'fefba785-82d0-464c-9706-658e233803a3');
