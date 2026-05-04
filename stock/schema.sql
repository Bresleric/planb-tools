-- =============================================================================
-- Module Stock — Phase A (matching étiquettes scannées ↔ articles)
-- =============================================================================
-- Date : 2026-05-04
-- Convention PlanB-Tools : RLS active mais policy permissive public_all
--
-- Ajoute 3 colonnes à scan_tracabilite pour permettre le rattachement
-- d'une étiquette scannée à un article du référentiel appro_ingredients.

ALTER TABLE public.scan_tracabilite
  ADD COLUMN IF NOT EXISTS article_id UUID REFERENCES public.appro_ingredients(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS match_par_id UUID,
  ADD COLUMN IF NOT EXISTS match_par_nom TEXT,
  ADD COLUMN IF NOT EXISTS match_at TIMESTAMPTZ;

COMMENT ON COLUMN public.scan_tracabilite.article_id IS 'Lien vers appro_ingredients : référence stable pour les calculs de stock. NULL tant que pas rattaché par admin.';

-- Index pour retrouver vite ce qui reste à rattacher
CREATE INDEX IF NOT EXISTS idx_scan_tracabilite_a_rattacher
  ON public.scan_tracabilite (created_at DESC)
  WHERE article_id IS NULL;

-- Index pour requêtes "stock par article"
CREATE INDEX IF NOT EXISTS idx_scan_tracabilite_article
  ON public.scan_tracabilite (article_id)
  WHERE article_id IS NOT NULL;
