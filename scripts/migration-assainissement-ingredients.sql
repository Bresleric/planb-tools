-- ============================================================================
-- Assainissement du referentiel ingredients / catalogue
-- Applique en PRODUCTION le 2026-06-12 via Supabase MCP (deja execute).
-- Conserve ici pour tracabilite et re-execution eventuelle. Idempotent.
-- Contexte : voir docs/ARCHITECTURE-DONNEES-INGREDIENTS.md
-- ============================================================================

-- 1) Raccrocher les lignes appro_catalogue orphelines (ingredient_id NULL)
--    a leur ingredient canonique. 5/8 traites (3 douteux laisses a Eric).
UPDATE appro_catalogue
SET ingredient_id = '5d35396a-320c-4b3f-9772-6d2e742b48e2'  -- Knack
WHERE id = '2459f954-6544-42f5-8290-1db54fbb8405' AND ingredient_id IS NULL;

UPDATE appro_catalogue c
SET ingredient_id = m.ing::uuid
FROM (VALUES
  ('STICKET',           'f36e303c-93a0-4e94-883b-98bdd0f70d1e'),  -- Sticks ketchup
  ('JAUNE D',           '6e7d9ead-e827-4a0c-b036-50b1127609a0'),  -- Jaunes d'Oeufs Liquide Brique
  ('MOUTARDE D''ALSACE','fb868b3c-fbf0-4251-b74d-a183c2e3f2ea'),  -- Moutarde d'Alsace douce
  ('AMER FDB ENVIE',    'cc15d102-7715-4d1b-b493-6df4243634c8')   -- AMER FDB ENVIE D'ETE 1
) AS m(prefixe, ing)
WHERE c.ingredient_id IS NULL AND c.nom LIKE m.prefixe || '%';

-- Orphelins NON traites (decision Eric) :
--   - Koch  "EPAULE D'AGNEAU ROULE S/OS"  (roule vs "coupe en saute" : produit different ?)
--   - Essentiel "TABLETTE LAVE VAISSELLE" (consommable, pas d'ingredient)
--   - Sapam "Frais d'eco participation"   (frais, pas un ingredient)

-- 2) Fusion des 3 doublons exacts (perdant -> gagnant) : re-pointe 5 tables
--    Farine        : 4ac4eca0 -> 2624e228
--    Fromage blanc : 3d60fdc0 -> adb5f86b
--    PDT Epluchees : d73d5b05 -> 96cbb868
DO $$
DECLARE
  m jsonb := '{
    "4ac4eca0-998d-4ee8-b140-c43d4b55adf8":"2624e228-91a4-4d1d-a2bf-95a3ba3f7f2f",
    "3d60fdc0-2831-4b3f-8f0b-71355acf5bb4":"adb5f86b-9046-46b4-91db-59d0462f5941",
    "d73d5b05-a18d-4af6-905d-e5f1fd9f00a2":"96cbb868-70b2-4910-a3d6-bb0e1298b805"
  }'::jsonb;
  k text;
BEGIN
  FOR k IN SELECT jsonb_object_keys(m) LOOP
    UPDATE appro_besoins          SET ingredient_id=(m->>k)::uuid WHERE ingredient_id=k::uuid;
    UPDATE appro_catalogue        SET ingredient_id=(m->>k)::uuid WHERE ingredient_id=k::uuid;
    UPDATE factures_achats_lignes SET ingredient_id=(m->>k)::uuid WHERE ingredient_id=k::uuid;
    UPDATE fiche_ingredients      SET article_id  =(m->>k)::uuid WHERE article_id  =k::uuid;
    UPDATE stock_mouvements       SET article_id  =(m->>k)::uuid WHERE article_id  =k::uuid;
  END LOOP;
END $$;

-- Desactiver + renommer les perdants (reversible, pas de suppression)
UPDATE appro_ingredients
SET actif = false, nom = nom || ' (doublon fusionne 2026-06-12)'
WHERE id IN ('4ac4eca0-998d-4ee8-b140-c43d4b55adf8',
             '3d60fdc0-2831-4b3f-8f0b-71355acf5bb4',
             'd73d5b05-a18d-4af6-905d-e5f1fd9f00a2')
  AND nom NOT LIKE '%(doublon fusionne%';

-- 3) Garde-fou anti-doublons : unicite du nom normalise parmi les actifs
CREATE UNIQUE INDEX IF NOT EXISTS appro_ingredients_nom_norm_uniq
ON appro_ingredients (
  lower(translate(nom,'àâäéèêëîïôöûüçÀÂÄÉÈÊËÎÏÔÖÛÜÇ','aaaeeeeiioouucAAAEEEEIIOOUUC'))
)
WHERE actif IS TRUE;
