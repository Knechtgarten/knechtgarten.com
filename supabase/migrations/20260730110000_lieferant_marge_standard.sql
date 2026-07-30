-- ============================================================================
-- Offertentool 2027 - Standard-Marge pro Lieferant: fuer Artikel, bei denen
-- nur der Verkaufspreis (VP Lieferant) bekannt ist, aber kein Einkaufspreis
-- (z.B. Crawling-Quellen, die nur einen oeffentlichen VK/UVP zeigen). Aus
-- dieser hinterlegten Standard-Marge wird dann ein angenommener Einkaufspreis
-- zurueckgerechnet (VP Lieferant x (1 - Standard-Marge/100)), der danach
-- genau gleich in die bestehende Einstand-/Margen-Rechnung einfliesst wie ein
-- echter Einkaufspreis. Rein eine Rechengrundlage - wird nie ins EK-Feld des
-- Artikels zurueckgeschrieben.
-- ============================================================================

alter table lieferant_datenabgleich add column marge_lieferant_standard_prozent numeric null;
