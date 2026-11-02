-- Planer Maschinen: vorläufige Reservation merkt sich die angeklickte Nummer (Wunsch).
-- Der Planer nimmt diese Nummer, wenn sie frei ist, sonst eine andere freie vom gleichen Typ.
alter table planer_ressource_einsatz
  add column if not exists wunsch_ressource_id uuid references planer_ressource(id) on delete set null;
