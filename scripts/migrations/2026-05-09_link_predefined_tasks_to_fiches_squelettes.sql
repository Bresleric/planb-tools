
WITH pairs(task_id, nom, cat) AS (
  VALUES 
    ('87fcf7d0-7f64-4a68-b819-8a649d6013e0'::uuid, 'Cuire cordon bleu', 'produit_intermediaire'),
    ('ad95298e-afa1-458e-b528-447959148b00'::uuid, 'Cuire PDT rôties', 'produit_intermediaire'),
    ('35c7d457-4a06-4fc9-9e43-0c151073de65'::uuid, 'Cuire PDT vapeur', 'produit_intermediaire'),
    ('0a81262f-4083-45e2-b89a-fd77d8f0a797'::uuid, 'Cuire viande choucroute', 'produit_intermediaire'),
    ('d2f9b341-8a89-49a6-ab31-873016a78ace'::uuid, 'Oeufs durs', 'produit_intermediaire'),
    ('78856d5f-d278-41b5-800f-01b248b5499d'::uuid, 'Poêler foie gras', 'produit_intermediaire'),
    ('7e4739dd-2733-467e-9519-45e8f9055bb6'::uuid, 'Couper champignons', 'mise_en_place'),
    ('a03a0d97-de0a-4c8c-b39c-71271be8664e'::uuid, 'Couper ciboulette', 'mise_en_place'),
    ('63673bce-7276-4182-8059-304b98a1506d'::uuid, 'Couper oignons rouges', 'mise_en_place'),
    ('02362772-2a5f-471c-990a-2e5650abcd12'::uuid, 'Couper pommes de terre', 'mise_en_place'),
    ('0a2300bb-2cd2-47ff-8cc7-b74aa79b9178'::uuid, 'Couper tomates cerises', 'mise_en_place'),
    ('3d58a9fe-ad6b-46ba-b988-c306ed08d0da'::uuid, 'Détailler poule', 'mise_en_place'),
    ('1b3151af-ae8c-4b5a-943e-ac134e1aa0f0'::uuid, 'Détailler rognons', 'mise_en_place'),
    ('654b732a-0879-4534-b1ee-bbd4ea0c130b'::uuid, 'Émincer oignons', 'mise_en_place'),
    ('19e4e76c-1480-4bc5-a05c-4754854a0247'::uuid, 'Éplucher asperges', 'mise_en_place'),
    ('9bcf4e82-bf0c-4906-8989-8167331b764e'::uuid, 'Éplucher carottes', 'mise_en_place'),
    ('11e164e5-fedf-4061-ab20-ed9d166af88c'::uuid, 'Éplucher oignons blancs', 'mise_en_place'),
    ('7dac8ef8-ac83-4d6a-afb4-67f3013ed445'::uuid, 'Éplucher oignons rouges', 'mise_en_place'),
    ('1b606393-4798-40a7-815f-3570f0346932'::uuid, 'Éplucher pommes', 'mise_en_place'),
    ('716d46d6-3058-4607-b656-a446205cad18'::uuid, 'Tailler cornichons', 'mise_en_place'),
    ('352a66d7-9289-4dc7-9aca-81af45089896'::uuid, 'Tailler noix de veau', 'mise_en_place'),
    ('86fe5755-afb8-40df-b26c-cc41a40370d2'::uuid, 'Tailler onglet', 'mise_en_place'),
    ('228105cc-35dd-4d75-81a1-26ebbe11b998'::uuid, 'Tailler paleron', 'mise_en_place'),
    ('67a4a033-ec87-49e8-ba27-772010cfab23'::uuid, 'Tailler rhubarbe', 'mise_en_place'),
    ('4b625aaa-cc4b-472d-9a4c-42d8a48d9fc4'::uuid, 'Asperges', 'produit_fini'),
    ('63369efb-0ad3-4f60-8db1-8b5dbe96b450'::uuid, 'Bibeleskäs', 'produit_fini'),
    ('1ad9d0a4-a74b-48fb-899d-3848393b9f64'::uuid, 'Carottes au miel', 'produit_fini'),
    ('0ad8195e-6ab4-4f59-b407-68f280a3e269'::uuid, 'Choucroute & garnitures', 'produit_fini'),
    ('d71463e9-7fb4-4803-b501-561bee96c848'::uuid, 'Choux rouge', 'produit_fini'),
    ('4cbba115-1902-4a3d-99ce-dae52610e9bd'::uuid, 'Fleischkiechle', 'produit_fini'),
    ('2b893ca5-42a5-4dcf-a8f2-46744737469a'::uuid, 'Galette de PDT', 'produit_fini'),
    ('22acaa12-da61-49a0-b3a9-0969e2c4bdf8'::uuid, 'Garnitures choucroute', 'produit_fini'),
    ('95fbbbee-dacd-4e8c-8e83-d653c4fab857'::uuid, 'Munsterflette', 'produit_fini'),
    ('7d458ea2-f575-452b-b9c5-13b8d6b786e2'::uuid, 'Purée', 'produit_fini'),
    ('040b0aea-f3a1-4d59-9f8f-4fe0acfe29e4'::uuid, 'Purée de céleri', 'produit_fini'),
    ('49623082-24c6-4900-a98c-136c79517cc8'::uuid, 'Soupe à l''oignon', 'produit_fini'),
    ('85f6de11-8a6b-4f16-aabb-28f9d753262e'::uuid, 'Caramel beurre salé', 'produit_fini'),
    ('21249f6a-5d56-4b50-bdae-146323bc22dd'::uuid, 'Charlotte fraises', 'produit_fini'),
    ('105b6fc5-b5a8-4620-a287-a628d9d29797'::uuid, 'Clafoutis', 'produit_fini'),
    ('5e002dc0-34b3-4446-a35c-adb1b769bc7d'::uuid, 'Crème brûlée', 'produit_fini'),
    ('3e5499b1-3006-4703-8ff6-b9038c1dea91'::uuid, 'Fond de tarte', 'produit_fini'),
    ('0de85384-8fe3-405f-82e7-4e0cdf8b7a90'::uuid, 'Forêt noire', 'produit_fini'),
    ('68328887-1366-40f2-9b03-8fb03500f185'::uuid, 'Génoise', 'produit_fini'),
    ('1d2a9192-d11e-4333-90ea-ec2556f6d039'::uuid, 'Île flottante', 'produit_fini'),
    ('a4dcd4a2-61ae-447e-910f-989f40f67b46'::uuid, 'Kässkuche', 'produit_fini'),
    ('cac47933-002b-40ba-a89e-937a603d0104'::uuid, 'Linzertorte', 'produit_fini'),
    ('5d9b6cd7-cc0f-4542-b5ae-286c82451103'::uuid, 'Meringue', 'produit_fini'),
    ('5114724b-aea4-4c7f-9bb0-ca65f255d6fe'::uuid, 'Parfait glacé', 'produit_fini'),
    ('1154a9e2-09c7-4e8a-9382-2f85bf042211'::uuid, 'Rieweleküche', 'produit_fini'),
    ('295801e1-3b87-4fb6-b4a5-9f27127473fd'::uuid, 'Soufflé glacé', 'produit_fini'),
    ('0a3ce723-10a4-4734-a3c1-ed2dfee09a61'::uuid, 'Tarte à l''oignon', 'produit_fini'),
    ('07261a35-964e-4cd2-9d67-74223508a5a9'::uuid, 'Tarte aux fruits', 'produit_fini'),
    ('8391f00b-8b5f-4e50-bf36-bfb6d2209319'::uuid, 'Tarte citron', 'produit_fini'),
    ('420488ca-7541-49f9-b2a4-82095ff936f7'::uuid, 'Tarte fromage blanc', 'produit_fini'),
    ('57a28df0-f23d-47b6-ba90-74a64eaf4040'::uuid, 'Tarte quetsches', 'produit_fini'),
    ('37d4fad9-9b34-44cb-b1bf-d77b44bf0c5b'::uuid, 'Tarte rhubarbe', 'produit_fini'),
    ('425b9c9d-a648-4742-84e3-3776bd52dec6'::uuid, 'Verrine forêt noire', 'produit_fini'),
    ('0ae87fd1-3224-42f5-8d9b-cbd6374e3bf1'::uuid, 'Préparer beurre escargot', 'mise_en_place'),
    ('21901119-f025-46f6-a4b3-9428e8b4083e'::uuid, 'Préparer cervelas', 'mise_en_place'),
    ('0f6a332c-16f6-4a9d-8790-b3f0c8c4eb43'::uuid, 'Préparer confit d''oignon', 'mise_en_place'),
    ('006deb3e-3013-4735-a209-4551fe8510a1'::uuid, 'Préparer cordon bleu', 'mise_en_place'),
    ('73a9734f-ee39-4a32-852a-2be6ecd0d422'::uuid, 'Préparer saumon confit', 'mise_en_place')
),
existing_fiches AS (
  SELECT p.task_id, p.nom, p.cat, ft.id AS existing_fiche_id
  FROM pairs p
  LEFT JOIN fiches_techniques ft 
    ON LOWER(ft.nom) = LOWER(p.nom) AND ft.etablissement = 'freddy'
),
inserted AS (
  INSERT INTO fiches_techniques (nom, categorie, etablissement, actif, notes)
  SELECT nom, cat, 'freddy', true, 
         'Squelette auto-créé le 2026-05-09 (mapping TAF). À enrichir : ingrédients, instructions, temps, DLC.'
  FROM existing_fiches
  WHERE existing_fiche_id IS NULL
  RETURNING id, nom
),
all_fiches AS (
  SELECT task_id, existing_fiche_id AS fiche_id, 'reused' AS source
  FROM existing_fiches
  WHERE existing_fiche_id IS NOT NULL
  UNION ALL
  SELECT ef.task_id, i.id AS fiche_id, 'created' AS source
  FROM existing_fiches ef
  JOIN inserted i ON LOWER(i.nom) = LOWER(ef.nom)
  WHERE ef.existing_fiche_id IS NULL
)
UPDATE predefined_tasks pt
SET fiche_id = af.fiche_id
FROM all_fiches af
WHERE pt.id = af.task_id
  AND pt.fiche_id IS NULL
RETURNING pt.id, pt.nom, af.fiche_id, af.source;
