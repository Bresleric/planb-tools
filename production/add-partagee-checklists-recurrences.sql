-- ============================================================
-- Migration Lot 2 : partagee sur taches_recurrentes + checklists
-- ============================================================
-- Pattern identique au Lot 1 (fiches_techniques.partagee) mais
-- DEFAULT false ici, car les données existantes ont été créées
-- séparément pour chaque établissement (24 checklists Liesel,
-- 7 Freddy, 6 récurrences réparties). Eric coche au cas par cas.
--
-- Lecture côté code :
--   .or(`etablissement.eq.${etab},partagee.eq.true`)
-- ============================================================

ALTER TABLE public.taches_recurrentes
  ADD COLUMN IF NOT EXISTS partagee boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.taches_recurrentes.partagee IS
  'TRUE = récurrence visible dans les 2 restaurants. FALSE (défaut) = visible uniquement chez `etablissement`.';

ALTER TABLE public.checklists
  ADD COLUMN IF NOT EXISTS partagee boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.checklists.partagee IS
  'TRUE = checklist visible dans les 2 restaurants. FALSE (défaut) = visible uniquement chez `etablissement`.';

-- Vérification : rien ne doit avoir changé côté visibilité par défaut
SELECT
  'taches_recurrentes' AS table_name,
  COUNT(*) FILTER (WHERE etablissement = 'freddy') AS freddy_only,
  COUNT(*) FILTER (WHERE etablissement = 'liesel') AS liesel_only,
  COUNT(*) FILTER (WHERE partagee = true) AS partagees,
  COUNT(*) AS total
FROM public.taches_recurrentes
UNION ALL
SELECT
  'checklists',
  COUNT(*) FILTER (WHERE etablissement = 'freddy'),
  COUNT(*) FILTER (WHERE etablissement = 'liesel'),
  COUNT(*) FILTER (WHERE partagee = true),
  COUNT(*)
FROM public.checklists;
