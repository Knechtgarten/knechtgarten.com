-- Easy-Vorlagen: mehrzeilige Easybill-Bezeichnungen einzeilig mit « / » (Bezeichnungsfeld im Blatt ist einzeilig)
update public.easy_vorlage_zeile set bezeichnung = regexp_replace(trim(bezeichnung), '\s*\n\s*', ' / ', 'g') where bezeichnung like E'%\n%';
