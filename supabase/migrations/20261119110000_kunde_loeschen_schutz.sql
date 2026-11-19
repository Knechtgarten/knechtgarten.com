-- Kunden mit Projekt, Bauprogramm, CAD-Plan oder Fotos dürfen nicht gelöscht werden
-- (bisher wurden diese mitgelöscht). Wie bei Offerte und Pflegeauftrag: «restrict».
alter table projekt     drop constraint projekt_kunde_id_fkey,     add constraint projekt_kunde_id_fkey     foreign key (kunde_id) references kunde(id) on delete restrict;
alter table bauprogramm drop constraint bauprogramm_kunde_id_fkey, add constraint bauprogramm_kunde_id_fkey foreign key (kunde_id) references kunde(id) on delete restrict;
alter table cad_plan    drop constraint cad_plan_kunde_id_fkey,    add constraint cad_plan_kunde_id_fkey    foreign key (kunde_id) references kunde(id) on delete restrict;
alter table foto_ablage drop constraint foto_ablage_kunde_id_fkey, add constraint foto_ablage_kunde_id_fkey foreign key (kunde_id) references kunde(id) on delete restrict;
