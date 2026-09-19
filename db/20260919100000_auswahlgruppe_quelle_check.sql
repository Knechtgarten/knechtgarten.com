-- ressourcenzeile_genau_eine_quelle_check (siehe sonderpositionen-v1.sql)
-- kannte Auswahlgruppe noch nicht als gueltige Preisquelle - Zeilen mit nur
-- auswahlgruppe_id gesetzt (siehe Tool B syncAuswahlgruppenZeile()) fielen
-- durch die Pruefung ("0 Quellen" statt der erwarteten 1).
alter table ressourcenzeile drop constraint ressourcenzeile_genau_eine_quelle_check;
alter table ressourcenzeile add constraint ressourcenzeile_genau_eine_quelle_check
  check (
    (case when artikel_id is not null then 1 else 0 end
     + case when staffelgruppe_id is not null then 1 else 0 end
     + case when zonengruppe_id is not null then 1 else 0 end
     + case when sonderposition_typ_id is not null then 1 else 0 end
     + case when auswahlgruppe_id is not null then 1 else 0 end) = 1
  );
