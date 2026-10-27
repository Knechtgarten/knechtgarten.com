-- Einsatzplaner: Liefertermine als Markierung (Paletten-Icon) mit Lieferant (Farbe)
-- art = 'liefer', lieferant = gruetter | fontarocca | diverse
alter table planer_markierung add column if not exists lieferant text null;
