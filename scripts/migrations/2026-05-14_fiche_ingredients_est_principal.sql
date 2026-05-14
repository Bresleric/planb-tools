-- ====================================================================
-- Migration — 2026-05-14 — fiche_ingredients.est_principal
--
-- Phase 1 du projet Scan-FEFO : permettre à l'admin de marquer
-- certains ingrédients d'une fiche technique comme "principaux".
-- Au démarrage du TAF correspondant, le système demandera de scanner
-- l'étiquette de ces ingrédients principaux (typiquement les matières
-- coûteuses, périssables ou critiques pour la traçabilité HACCP).
--
-- Exemple : fiche "Choucroute" (13 ingrédients) — marquer comme
-- principaux : choucroute crue, lard fumé, saucisses. Les épices et
-- le sel restent en "non principaux", pas scannés.
--
-- DEFAULT false : aucune fiche ne fonctionne différemment tant qu'on
-- ne marque rien. Migration 100% additive et compatible.
-- ====================================================================

BEGIN;

ALTER TABLE public.fiche_ingredients
  ADD COLUMN IF NOT EXISTS est_principal BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN public.fiche_ingredients.est_principal IS
  'true = ingrédient à scanner obligatoirement au démarrage de la tâche de production correspondante. Sert au workflow Scan-FEFO (lot scanné → matching article → sortie de stock + alerte FEFO).';

-- Index partiel pour requête rapide des ingrédients à scanner
CREATE INDEX IF NOT EXISTS idx_fiche_ingredients_est_principal
  ON public.fiche_ingredients (fiche_id)
  WHERE est_principal = true;

COMMIT;

-- ====================================================================
-- Validation post-exécution
-- ====================================================================
-- Vérifier la colonne :
-- SELECT column_name, data_type, column_default, is_nullable
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'fiche_ingredients'
--   AND column_name = 'est_principal';
--
-- Aucun ingrédient n'est marqué principal au début (attendu : 0) :
-- SELECT COUNT(*) FROM fiche_ingredients WHERE est_principal = true;
--
-- Total d'ingrédients (pour rappel, attendu : 162 ou proche) :
-- SELECT COUNT(*) FROM fiche_ingredients;
