-- Füllhöhe nie negativ (leere Offerten: Tiefe 0, Kragen 25 cm): (x > 0) × x
update term set ausdruck = jsonb_build_object('op', '*', 'args', jsonb_build_array(
    jsonb_build_object('op', '>', 'args', jsonb_build_array(ausdruck, jsonb_build_object('lit', 0))), ausdruck))
where name = 'Füllhöhe Hinterfüllung' and offertentyp_id = '83bf9ae8-3095-4194-a9bb-4ea2dc08473e' and ausdruck->>'op' = '-';
