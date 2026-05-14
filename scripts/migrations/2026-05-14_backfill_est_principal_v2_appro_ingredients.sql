-- ====================================================================
-- Migration V2 — 2026-05-14 — Backfill est_principal=true (CORRIGÉ)
--
-- ⚠ La V1 (2026-05-14_backfill_est_principal_carnes_laitiers.sql)
-- joignait sur appro_catalogue. Mais fiche_ingredients.article_id
-- pointe en réalité vers appro_ingredients (366 lignes, table dédiée
-- pour les ingrédients de fiche). Résultat : 0 ligne affectée.
--
-- Cette V2 cible la bonne table appro_ingredients qui a :
--   - Catégorie 'Viande & charcuterie' (26 articles)
--   - Catégorie 'Poisson' (1)
--   - Catégorie 'Frais' (18) avec mots-clés carnés/laitiers
--   - Catégorie 'Surgelés' (4) avec mots-clés carnés
--   - Catégorie 'Oeufs' (3) — bonus : catégorie dédiée propre
--
-- Idempotent : UPDATE WHERE est_principal = false uniquement.
-- ====================================================================

BEGIN;

UPDATE public.fiche_ingredients fi
SET est_principal = true
WHERE fi.est_principal = false
  AND fi.article_id IS NOT NULL
  AND fi.article_id IN (
    SELECT ai.id FROM public.appro_ingredients ai
    WHERE ai.actif = true
      AND (
        -- 1) Viandes, charcuteries, poissons (catégories propres)
        ai.categorie IN ('Viande & charcuterie', 'Poisson')
        -- 2) Œufs (catégorie dédiée dans appro_ingredients — n'existait pas dans appro_catalogue)
        OR ai.categorie = 'Oeufs'
        -- 3) Frais & Surgelés : carnés (mots-clés)
        OR (ai.categorie IN ('Frais', 'Surgelés')
            AND ai.nom ~* '(boeuf|veau|agneau|porc|canard|poulet|dinde|lapin|jambon|lard|lardon|knack|cervelas|gendarme|kassler|paleron|onglet|rognon|jarret|filet|épaule|epaule|escalope|cuisse|saumon|poisson|tourte\s+marinee|foie\s+gras)')
        -- 4) Frais : laitiers
        OR (ai.categorie = 'Frais'
            AND ai.nom ~* '(beurre|crème|creme|fromage|emmental|munster|mascarpone|tiramisu|lait|yaourt|mozzarella|brie|camembert|cheddar|ricotta|feta|gouda)')
      )
  );

COMMIT;

-- ====================================================================
-- Validation post-exécution
-- ====================================================================
-- Doit afficher un nombre significatif (entre 30 et 80) :
-- SELECT COUNT(*) AS nb_principaux FROM fiche_ingredients WHERE est_principal = true;
--
-- Liste détaillée :
-- SELECT ft.nom AS fiche, fi.nom AS ingredient, ai.categorie
-- FROM fiche_ingredients fi
-- JOIN fiches_techniques ft ON ft.id = fi.fiche_id
-- LEFT JOIN appro_ingredients ai ON ai.id = fi.article_id
-- WHERE fi.est_principal = true AND ft.actif = true
-- ORDER BY ft.nom, fi.ordre;
