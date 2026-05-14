-- ====================================================================
-- Migration — 2026-05-14 — fiches_techniques : champs TAF intégrés
--
-- Phase 1 sur 3 de la fusion predefined_tasks ↔ fiches_techniques.
-- L'objectif final : faire des fiches techniques la source unique pour
-- TOUTES les tâches de production. Les predefined_tasks ne garderont
-- que les non-production (Nettoyer, Vérifier, etc.).
--
-- Cette phase est purement additive : on ajoute 5 colonnes à
-- fiches_techniques et on backfille depuis les predefined_tasks qui
-- pointent vers chaque fiche. Aucune suppression. Le code existant
-- continue à fonctionner exactement comme avant.
--
-- Validations préalables :
--   - 0 fiche n'a plus d'1 predefined_task qui pointe vers elle
--     (vérifié SELECT JOIN GROUP BY HAVING COUNT > 1)
--   - Aucune des 5 colonnes n'existe déjà
-- ====================================================================

BEGIN;

-- 1. Ajout des 5 colonnes
ALTER TABLE public.fiches_techniques
  ADD COLUMN IF NOT EXISTS equipe        TEXT DEFAULT 'cuisine',
  ADD COLUMN IF NOT EXISTS creneau       TEXT DEFAULT 'Matin',
  ADD COLUMN IF NOT EXISTS categorie_taf TEXT,
  ADD COLUMN IF NOT EXISTS produit       TEXT,
  ADD COLUMN IF NOT EXISTS action        TEXT;

COMMENT ON COLUMN public.fiches_techniques.equipe IS
  'Équipe qui exécute la tâche : cuisine/salle/plonge/autre. Hérité des predefined_tasks lors de la fusion 14/5/2026.';
COMMENT ON COLUMN public.fiches_techniques.creneau IS
  'Créneau par défaut : Matin/Midi/Soir.';
COMMENT ON COLUMN public.fiches_techniques.categorie_taf IS
  'Catégorie côté TAF (Cuissons, Pâtisserie, Découpes & Épluchage, etc.) — distincte de fiches_techniques.categorie qui est la catégorie de production (mise_en_place / produit_intermediaire / produit_fini).';
COMMENT ON COLUMN public.fiches_techniques.produit IS
  'Composante "produit" de la tâche (ex: Carottes, Œufs).';
COMMENT ON COLUMN public.fiches_techniques.action IS
  'Composante "action" de la tâche (ex: Éplucher, Cuire).';

-- 2. Index pour requêtes futures (recherche/filtre par equipe/créneau)
CREATE INDEX IF NOT EXISTS idx_fiches_techniques_equipe
  ON public.fiches_techniques (equipe)
  WHERE actif = true;
CREATE INDEX IF NOT EXISTS idx_fiches_techniques_categorie_taf
  ON public.fiches_techniques (categorie_taf)
  WHERE actif = true AND categorie_taf IS NOT NULL;

-- 3. Backfill depuis predefined_tasks qui pointe vers chaque fiche
-- COALESCE pour ne pas écraser ce qu'on aurait déjà mis en valeur par défaut
UPDATE public.fiches_techniques ft
SET
  equipe        = COALESCE(NULLIF(ft.equipe, 'cuisine'), pt.equipe, 'cuisine'),
  creneau       = COALESCE(NULLIF(ft.creneau, 'Matin'),  pt.creneau, 'Matin'),
  categorie_taf = COALESCE(ft.categorie_taf, pt.categorie),
  produit       = COALESCE(ft.produit,       pt.produit),
  action        = COALESCE(ft.action,        pt.action)
FROM public.predefined_tasks pt
WHERE pt.fiche_id = ft.id
  AND pt.actif = true
  AND ft.actif = true;

COMMIT;

-- ====================================================================
-- Validation post-exécution (à lancer après le COMMIT)
-- ====================================================================
-- Colonnes ajoutées :
-- SELECT column_name, data_type, column_default FROM information_schema.columns
--   WHERE table_schema = 'public' AND table_name = 'fiches_techniques'
--     AND column_name IN ('equipe','creneau','categorie_taf','produit','action');
--
-- Backfill stats :
-- SELECT
--   COUNT(*) AS total_actives,
--   COUNT(*) FILTER (WHERE categorie_taf IS NOT NULL) AS avec_cat_taf,
--   COUNT(*) FILTER (WHERE produit IS NOT NULL) AS avec_produit,
--   COUNT(*) FILTER (WHERE action IS NOT NULL) AS avec_action,
--   COUNT(*) FILTER (WHERE equipe <> 'cuisine') AS equipe_non_defaut
-- FROM fiches_techniques WHERE actif = true;
--
-- Fiches orphelines (sans predef → champs TAF restés au défaut) :
-- SELECT nom, equipe, creneau, categorie_taf, produit, action FROM fiches_techniques ft
--   WHERE ft.actif = true
--     AND NOT EXISTS (SELECT 1 FROM predefined_tasks pt WHERE pt.fiche_id = ft.id AND pt.actif = true);
