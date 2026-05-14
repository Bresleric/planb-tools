-- ====================================================================
-- Validation Phase 1 — à exécuter APRÈS la migration principale.
-- Lance les 3 requêtes ci-dessous dans Supabase Studio SQL Editor.
-- ====================================================================

-- ============================================
-- REQUÊTE 1 — Les 5 colonnes existent-elles ?
-- Attendu : 5 lignes (equipe, creneau, categorie_taf, produit, action)
-- ============================================
SELECT
  column_name,
  data_type,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'fiches_techniques'
  AND column_name IN ('equipe', 'creneau', 'categorie_taf', 'produit', 'action')
ORDER BY column_name;


-- ============================================
-- REQUÊTE 2 — Stats du backfill
-- Attendu (env.) : 91 actives, ~70 avec cat_taf, ~70 avec produit/action,
-- 0-5 equipe_non_defaut (vu que predef.equipe = 'cuisine' partout).
-- ============================================
SELECT
  COUNT(*) AS total_actives,
  COUNT(*) FILTER (WHERE categorie_taf IS NOT NULL) AS avec_cat_taf,
  COUNT(*) FILTER (WHERE produit IS NOT NULL) AS avec_produit,
  COUNT(*) FILTER (WHERE action IS NOT NULL) AS avec_action,
  COUNT(*) FILTER (WHERE equipe <> 'cuisine') AS equipe_non_defaut,
  COUNT(*) FILTER (WHERE creneau <> 'Matin') AS creneau_non_defaut
FROM fiches_techniques
WHERE actif = true;


-- ============================================
-- REQUÊTE 3 — Fiches orphelines (sans predef)
-- Ces fiches ont leurs champs TAF aux valeurs par défaut (cuisine/Matin)
-- et categorie_taf/produit/action à NULL. Listées pour info.
-- ============================================
SELECT
  ft.nom,
  ft.equipe,
  ft.creneau,
  ft.categorie_taf,
  ft.produit,
  ft.action
FROM fiches_techniques ft
WHERE ft.actif = true
  AND NOT EXISTS (
    SELECT 1 FROM predefined_tasks pt
    WHERE pt.fiche_id = ft.id AND pt.actif = true
  )
ORDER BY ft.nom;
