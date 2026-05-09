-- ====================================================================
-- Migration v2 — 2026-05-09 — fusion doublons + predefs orphelines
--
-- Effets attendus :
-- 1. FUSION : 4 paires squelette/fiche-riche détectées + 1 cas spécial
--    (Galette de PDT vs Galettes de Pommes de terre).
--    → predefined_tasks redirigées vers la fiche riche
--    → squelettes désactivés
-- 2. RÉPARATION : 1 squelette manquant (Tailler onglet — la migration v1
--    avait sauté cet INSERT pour une raison non identifiée)
-- 3. CRÉATION : 19 predefined_tasks pour les fiches orphelines
--    (catégorie/équipe/créneau préalloués selon le nom)
--
-- Idempotent : peut être relancé sans dégât.
-- ====================================================================

BEGIN;

-- =========================
-- PARTIE 1 — Fusion 4 doublons
-- =========================

-- Crèmes brûlées
UPDATE predefined_tasks SET fiche_id = '1dc0bb80-3f48-41cb-956b-953a674e8291'::uuid 
WHERE fiche_id = '77a58e52-3a67-4cb0-a417-abec01406db5'::uuid;
UPDATE fiches_techniques 
SET actif = false, 
    notes = COALESCE(notes,'') || ' [Désactivé 2026-05-09 : doublon avec ' || 'Crèmes brûlées' || ']'
WHERE id = '77a58e52-3a67-4cb0-a417-abec01406db5'::uuid AND actif = true;

-- Kassküche
UPDATE predefined_tasks SET fiche_id = 'ae3ebb34-d606-4b17-afeb-654be676481a'::uuid 
WHERE fiche_id = '2aadf8e2-fd30-409b-8752-29e30ee7b2dc'::uuid;
UPDATE fiches_techniques 
SET actif = false, 
    notes = COALESCE(notes,'') || ' [Désactivé 2026-05-09 : doublon avec ' || 'Kassküche' || ']'
WHERE id = '2aadf8e2-fd30-409b-8752-29e30ee7b2dc'::uuid AND actif = true;

-- Tarte à l’oignon
UPDATE predefined_tasks SET fiche_id = '4738036c-9634-4a98-809b-90ce4ace6ef2'::uuid 
WHERE fiche_id = '1752c4ea-a7ef-4ea4-b65c-92447f908e84'::uuid;
UPDATE fiches_techniques 
SET actif = false, 
    notes = COALESCE(notes,'') || ' [Désactivé 2026-05-09 : doublon avec ' || 'Tarte à l’oignon' || ']'
WHERE id = '1752c4ea-a7ef-4ea4-b65c-92447f908e84'::uuid AND actif = true;

-- Fonds de tarte
UPDATE predefined_tasks SET fiche_id = '9c71673a-35e0-4369-81e5-64b12b2a82ed'::uuid 
WHERE fiche_id = '2770b970-f1aa-4fff-a85d-829cdf1ddedb'::uuid;
UPDATE fiches_techniques 
SET actif = false, 
    notes = COALESCE(notes,'') || ' [Désactivé 2026-05-09 : doublon avec ' || 'Fonds de tarte' || ']'
WHERE id = '2770b970-f1aa-4fff-a85d-829cdf1ddedb'::uuid AND actif = true;

-- =========================
-- PARTIE 2 — Cas spéciaux (predef sans fiche_id après v1)
-- =========================

-- Galette de PDT → relier à Galettes de Pommes de terre (existante)
UPDATE predefined_tasks SET fiche_id = '7ab9f53d-e82d-44c2-943d-3e41f1c021a5'::uuid
WHERE id = '2b893ca5-42a5-4dcf-a8f2-46744737469a'::uuid AND fiche_id IS NULL;

-- Tailler onglet → créer le squelette manquant + relier
WITH new_skel AS (
  INSERT INTO fiches_techniques (nom, categorie, etablissement, actif, notes)
  SELECT 'Tailler onglet', 'mise_en_place', 'freddy', true, 
         'Squelette auto-créé le 2026-05-09 v2 (réparation migration). À enrichir.'
  WHERE NOT EXISTS (
    SELECT 1 FROM fiches_techniques 
    WHERE nom = 'Tailler onglet' AND etablissement = 'freddy' AND actif = true
  )
  RETURNING id
)
UPDATE predefined_tasks pt
SET fiche_id = COALESCE(
    (SELECT id FROM new_skel),
    (SELECT id FROM fiches_techniques WHERE nom = 'Tailler onglet' AND etablissement = 'freddy' AND actif = true LIMIT 1)
)
WHERE pt.id = '86fe5755-afb8-40df-b26c-cc41a40370d2'::uuid AND pt.fiche_id IS NULL;

-- =========================
-- PARTIE 3 — 19 nouvelles predefined_tasks pour fiches orphelines
-- =========================

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Babas au Rhum', 'Pâtisserie', 'cuisine', 'Matin', true, 'a593e744-d863-498d-924d-e1887e38bee4'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Babas au Rhum' AND pt.fiche_id = 'a593e744-d863-498d-924d-e1887e38bee4'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Beurre Clarifié', 'Préparations', 'cuisine', 'Matin', true, '760d79e8-c4d1-42d0-81fd-8fc3cd158cab'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Beurre Clarifié' AND pt.fiche_id = '760d79e8-c4d1-42d0-81fd-8fc3cd158cab'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Beurre d’escargot', 'Préparations', 'cuisine', 'Matin', true, '4673db13-86f0-4d0b-8c64-dcefca02063b'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Beurre d’escargot' AND pt.fiche_id = '4673db13-86f0-4d0b-8c64-dcefca02063b'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Carottes - Tronçon', 'Découpes & Épluchage', 'cuisine', 'Matin', true, '0a3c26ec-4265-4eff-83b5-dc1174147b0f'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Carottes - Tronçon' AND pt.fiche_id = '0a3c26ec-4265-4eff-83b5-dc1174147b0f'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Cordons Bleus Finis', 'Préparations', 'cuisine', 'Matin', true, '5c2d6d07-d897-4174-90e4-66d70a068b4b'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Cordons Bleus Finis' AND pt.fiche_id = '5c2d6d07-d897-4174-90e4-66d70a068b4b'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Cordons Bleus S/V Crus', 'Préparations', 'cuisine', 'Matin', true, 'aeff6b1b-7d4f-4ca0-a144-07b3999d0af8'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Cordons Bleus S/V Crus' AND pt.fiche_id = 'aeff6b1b-7d4f-4ca0-a144-07b3999d0af8'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Cordons Bleus S/V Cuits', 'Préparations', 'cuisine', 'Matin', true, 'ce371bd9-7b0b-42c7-bebf-b556c744282f'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Cordons Bleus S/V Cuits' AND pt.fiche_id = 'ce371bd9-7b0b-42c7-bebf-b556c744282f'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Fonds Moule à Manqué', 'Pâtisserie', 'cuisine', 'Matin', true, '1b3ae620-a610-49dd-9079-ec34ddc1535c'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Fonds Moule à Manqué' AND pt.fiche_id = '1b3ae620-a610-49dd-9079-ec34ddc1535c'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Garnitures Cordons bleus', 'Préparations', 'cuisine', 'Matin', true, 'e902f20f-ba43-4a7e-bb45-7d40bc3be9f3'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Garnitures Cordons bleus' AND pt.fiche_id = 'e902f20f-ba43-4a7e-bb45-7d40bc3be9f3'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Génoise chocolat (Forêt Noire)', 'Pâtisserie', 'cuisine', 'Matin', true, '1e23da33-68ac-4517-9c39-9b47359a3cd7'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Génoise chocolat (Forêt Noire)' AND pt.fiche_id = '1e23da33-68ac-4517-9c39-9b47359a3cd7'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Génoise pour bûche', 'Pâtisserie', 'cuisine', 'Matin', true, 'b7435883-338b-4447-8184-2b0a59dd8437'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Génoise pour bûche' AND pt.fiche_id = 'b7435883-338b-4447-8184-2b0a59dd8437'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Onglet - Parer et portionner', 'Découpes & Épluchage', 'cuisine', 'Matin', true, '54d2a78e-1e93-4274-82bc-beb924c4b1e9'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Onglet - Parer et portionner' AND pt.fiche_id = '54d2a78e-1e93-4274-82bc-beb924c4b1e9'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Parfait Glacé Fleur de bière', 'Pâtisserie', 'cuisine', 'Matin', true, 'f8b5fae9-a4bd-4a4b-a551-14502691d2e1'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Parfait Glacé Fleur de bière' AND pt.fiche_id = 'f8b5fae9-a4bd-4a4b-a551-14502691d2e1'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Préparer pâte à tarte', 'Pâtisserie', 'cuisine', 'Matin', true, '4361e112-79d1-4def-981a-5051b6c2d8aa'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Préparer pâte à tarte' AND pt.fiche_id = '4361e112-79d1-4def-981a-5051b6c2d8aa'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Préparer sauce bouchée', 'Préparations', 'cuisine', 'Matin', true, '4923de69-a007-472b-916b-ee01f56b8fcc'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Préparer sauce bouchée' AND pt.fiche_id = '4923de69-a007-472b-916b-ee01f56b8fcc'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Préparer sauce Munster', 'Préparations', 'cuisine', 'Matin', true, 'ceef88f4-d224-4f8c-b106-a068b4916151'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Préparer sauce Munster' AND pt.fiche_id = 'ceef88f4-d224-4f8c-b106-a068b4916151'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Préparer sauce poisson', 'Préparations', 'cuisine', 'Matin', true, '5da34428-5bae-4c27-a553-570f0953e74c'::uuid, 'mise_en_place', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Préparer sauce poisson' AND pt.fiche_id = '5da34428-5bae-4c27-a553-570f0953e74c'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Saumon confit', 'Préparations', 'cuisine', 'Matin', true, '552303ce-168e-4ba1-87eb-367ecd7eb321'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Saumon confit' AND pt.fiche_id = '552303ce-168e-4ba1-87eb-367ecd7eb321'::uuid
);

INSERT INTO predefined_tasks (nom, categorie, equipe, creneau, is_production, fiche_id, categorie_production, actif)
SELECT 'Préparer vinaigrette', 'Préparations', 'cuisine', 'Matin', true, '6b8d175a-173d-4b83-b240-b78e571774cb'::uuid, 'produit_fini', true
WHERE NOT EXISTS (
  SELECT 1 FROM predefined_tasks pt 
  WHERE pt.nom = 'Préparer vinaigrette' AND pt.fiche_id = '6b8d175a-173d-4b83-b240-b78e571774cb'::uuid
);

COMMIT;

-- ====================================================================
-- Validation post-exécution (à lancer après le COMMIT)
-- ====================================================================
-- SELECT COUNT(*) AS fiches_actives FROM fiches_techniques WHERE actif = true;
-- SELECT COUNT(*) AS predefs_actives FROM predefined_tasks WHERE actif = true;
-- SELECT COUNT(*) AS fiches_sans_predef FROM fiches_techniques ft
--   WHERE ft.actif = true AND NOT EXISTS (SELECT 1 FROM predefined_tasks pt WHERE pt.fiche_id = ft.id);
-- SELECT COUNT(*) AS predefs_production_sans_fiche FROM predefined_tasks 
--   WHERE actif = true AND is_production = true AND fiche_id IS NULL;
