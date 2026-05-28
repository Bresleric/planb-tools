-- ============================================================
-- Migration : fiches_techniques.partagee
-- ============================================================
-- Contexte : Freddy et Liesel ont la même carte à ~99%.
-- Avant cette migration, les fiches techniques étaient strictement
-- rattachées à un seul établissement (`etablissement`), ce qui rendait
-- la création de TAF impossible côté Liesel (0 fiche en base pour Liesel,
-- 122 pour Freddy).
--
-- On ajoute un drapeau `partagee` (booléen) :
--   * true  (DÉFAUT) → fiche visible dans les 2 restaurants
--   * false           → fiche visible UNIQUEMENT chez `etablissement`
--
-- Le défaut TRUE évite à Eric de cocher manuellement ~120 cases.
-- Il décochera au cas par cas les fiches strictement spécifiques à un resto.
--
-- Lecture côté code :
--   .or(`etablissement.eq.${etab},partagee.eq.true`)
--
-- À exécuter dans le SQL editor Supabase.
-- ============================================================

ALTER TABLE public.fiches_techniques
  ADD COLUMN IF NOT EXISTS partagee boolean NOT NULL DEFAULT true;

COMMENT ON COLUMN public.fiches_techniques.partagee IS
  'TRUE = fiche visible dans les 2 restaurants (carte commune). FALSE = visible uniquement chez `etablissement`. Défaut TRUE car carte commune à 99%.';

-- Vérification : combien de fiches sont désormais visibles côté Liesel ?
-- (= fiches Liesel propres + toutes les fiches partagées)
SELECT
  COUNT(*) FILTER (WHERE etablissement = 'liesel' OR partagee = true) AS visibles_liesel,
  COUNT(*) FILTER (WHERE etablissement = 'freddy' OR partagee = true) AS visibles_freddy,
  COUNT(*) AS total
FROM public.fiches_techniques
WHERE actif = true;
