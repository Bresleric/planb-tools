-- ====================================================================
-- Migration — 2026-05-14 — Backfill bulk est_principal=true
--
-- Objectif : marquer en masse comme "principaux" les ingrédients qui
-- sont des produits carnés (viande, charcuterie, poisson) ou laitiers
-- (lait, fromage, beurre, crème, œufs). Ces ingrédients devront être
-- scannés au démarrage de la tâche de production correspondante.
--
-- Approche pragmatique : on cible 71 articles du catalogue :
--   - Catégorie "Viande & charcuterie" (33)
--   - Catégorie "Poisson" (3)
--   - Catégorie "Frais" ou "Surgelés" avec mot-clé carné (23)
--   - Catégorie "Frais" avec mot-clé laitier ou œuf (12)
--
-- Tous les fiche_ingredients qui pointent vers un de ces articles sont
-- marqués est_principal = true. Idempotent : un re-run ne fait rien
-- si tout est déjà marqué.
--
-- Pré-requis : migration 2026-05-14_fiche_ingredients_est_principal.sql
-- doit être appliquée (colonne est_principal créée).
-- ====================================================================

BEGIN;

-- === DRY-RUN : lister les articles qui vont être ciblés (avant UPDATE) ===
-- Décommente cette requête pour voir la liste avant d'appliquer :
-- SELECT
--   ac.nom, ac.categorie,
--   CASE
--     WHEN ac.categorie = 'Viande & charcuterie' THEN 'Carné'
--     WHEN ac.categorie = 'Poisson' THEN 'Carné (poisson)'
--     WHEN ac.categorie IN ('Frais','Surgelés') AND ac.nom ~* '(boeuf|veau|agneau|porc|canard|poulet|dinde|lapin|jambon|lard|lardon|knack|cervelas|gendarme|kassler|paleron|onglet|rognon|jarret|filet|épaule|epaule|escalope|cuisse|saumon|poisson|tourte\s+marinee|foie\s+gras)' THEN 'Carné (Frais/Surgelé)'
--     WHEN ac.categorie = 'Frais' AND ac.nom ~* '(beurre|crème|creme|fromage|emmental|munster|mascarpone|tiramisu|lait|yaourt|mozzarella|brie|camembert|cheddar|ricotta|feta|gouda|oeuf|œuf|jaune)' THEN 'Laitier/Œuf'
--   END AS type
-- FROM appro_catalogue ac
-- WHERE ac.actif = true AND (
--   ac.categorie IN ('Viande & charcuterie','Poisson')
--   OR (ac.categorie IN ('Frais','Surgelés') AND ac.nom ~* '(boeuf|veau|agneau|porc|canard|poulet|dinde|lapin|jambon|lard|lardon|knack|cervelas|gendarme|kassler|paleron|onglet|rognon|jarret|filet|épaule|epaule|escalope|cuisse|saumon|poisson|tourte\s+marinee|foie\s+gras)')
--   OR (ac.categorie = 'Frais' AND ac.nom ~* '(beurre|crème|creme|fromage|emmental|munster|mascarpone|tiramisu|lait|yaourt|mozzarella|brie|camembert|cheddar|ricotta|feta|gouda|oeuf|œuf|jaune)')
-- )
-- ORDER BY type, ac.nom;

-- === UPDATE bulk ===
UPDATE public.fiche_ingredients fi
SET est_principal = true
WHERE fi.est_principal = false  -- idempotent : ne touche que ceux pas encore marqués
  AND fi.article_id IS NOT NULL
  AND fi.article_id IN (
    SELECT ac.id FROM public.appro_catalogue ac
    WHERE ac.actif = true
      AND (
        -- 1) Toutes les viandes & charcuteries
        ac.categorie = 'Viande & charcuterie'
        -- 2) Tous les poissons (catégorie dédiée)
        OR ac.categorie = 'Poisson'
        -- 3) Frais & Surgelés : carnés (mots-clés)
        OR (ac.categorie IN ('Frais', 'Surgelés')
            AND ac.nom ~* '(boeuf|veau|agneau|porc|canard|poulet|dinde|lapin|jambon|lard|lardon|knack|cervelas|gendarme|kassler|paleron|onglet|rognon|jarret|filet|épaule|epaule|escalope|cuisse|saumon|poisson|tourte\s+marinee|foie\s+gras)')
        -- 4) Frais : laitiers + œufs
        OR (ac.categorie = 'Frais'
            AND ac.nom ~* '(beurre|crème|creme|fromage|emmental|munster|mascarpone|tiramisu|lait|yaourt|mozzarella|brie|camembert|cheddar|ricotta|feta|gouda|oeuf|œuf|jaune)')
      )
  );

COMMIT;

-- ====================================================================
-- Validation post-exécution
-- ====================================================================
-- Combien d'ingrédients sont maintenant marqués principaux ?
-- SELECT COUNT(*) AS nb_principaux FROM fiche_ingredients WHERE est_principal = true;
--
-- Lister les ingrédients principaux par fiche (pour vérification visuelle) :
-- SELECT ft.nom AS fiche, fi.nom AS ingredient, ac.categorie
-- FROM fiche_ingredients fi
-- JOIN fiches_techniques ft ON ft.id = fi.fiche_id
-- LEFT JOIN appro_catalogue ac ON ac.id = fi.article_id
-- WHERE fi.est_principal = true AND ft.actif = true
-- ORDER BY ft.nom, fi.ordre;
--
-- Fiches sans aucun ingrédient principal (potentiellement à compléter) :
-- SELECT ft.nom FROM fiches_techniques ft
-- WHERE ft.actif = true
--   AND NOT EXISTS (
--     SELECT 1 FROM fiche_ingredients fi
--     WHERE fi.fiche_id = ft.id AND fi.est_principal = true
--   )
-- ORDER BY ft.nom;
