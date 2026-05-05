-- =============================================================================
-- Module Production — verrouillage saisie production
-- =============================================================================
-- Date : 2026-05-04
-- Ajoute la colonne a_creer_motif à productions :
--   - NULL si la production est rattachée à une fiche (cas normal)
--   - texte si la production a été saisie comme "Nouveau produit" et nécessite
--     soit la création d'une nouvelle fiche, soit un rattachement par admin

ALTER TABLE public.productions
  ADD COLUMN IF NOT EXISTS a_creer_motif TEXT;

CREATE INDEX IF NOT EXISTS idx_productions_a_creer
  ON public.productions (created_at DESC)
  WHERE fiche_id IS NULL AND a_creer_motif IS NOT NULL;

COMMENT ON COLUMN public.productions.a_creer_motif IS
  'Description saisie par le producteur quand le produit n''existe pas encore comme fiche technique. À traiter par un admin (créer une nouvelle fiche ou rattacher à une fiche existante).';
