-- =============================================================================
-- Module Stock — Migration : fiches techniques ↔ articles (produits intermédiaires)
-- =============================================================================
-- Date : 2026-05-04
-- Ajoute la colonne article_id à fiches_techniques pour matérialiser les
-- produits intermédiaires (semi-finis maison : fonds de tarte, sauces, mirepoix…).
-- Une fiche peut désormais être liée à un article du référentiel — c'est ce qu'elle produit.

ALTER TABLE public.fiches_techniques
  ADD COLUMN IF NOT EXISTS article_id UUID REFERENCES public.appro_ingredients(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_fiches_techniques_article ON public.fiches_techniques (article_id) WHERE article_id IS NOT NULL;

COMMENT ON COLUMN public.fiches_techniques.article_id IS 'Lien vers l''article que cette fiche produit (utilisé pour les semi-finis maison utilisés comme ingrédients dans d''autres fiches).';
