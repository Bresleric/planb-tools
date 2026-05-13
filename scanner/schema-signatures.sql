-- =============================================================================
-- Module Scanner / Stock — Identification visuelle automatique des produits
-- =============================================================================
-- Date : 2026-05-13
-- À exécuter dans Supabase SQL Editor (projet dzrherfavgiuygnimtux)
-- AVANT de déployer la nouvelle version de extract-document/index.ts
--
-- Permet de reconnaître automatiquement un produit récurrent (ex: choucroute Weber
-- en seau bleu) à partir d'indices visuels extraits par Claude Vision + libellé.
-- =============================================================================

-- 1. Table catalogue de signatures
CREATE TABLE IF NOT EXISTS public.produits_signatures (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Identification produit
  fournisseur_nom TEXT NOT NULL,
  produit_canonique TEXT NOT NULL,
  poids_attendu_kg NUMERIC,
  unite_attendue TEXT,

  -- Indices visuels (issus de Claude Vision)
  couleur_contenant TEXT,           -- 'bleu' | 'blanc' | 'transparent' | 'vert' | 'rouge' | 'jaune' | 'noir' | 'marron' | 'autre'
  type_contenant TEXT,              -- 'seau' | 'sachet_sous_vide' | 'sachet_opaque' | 'barquette' | 'carton' | 'bidon' | 'bocal' | 'autre'
  taille_apparente TEXT,            -- 'petit' | 'moyen' | 'grand'

  -- Indices textuels
  mots_cles TEXT[] DEFAULT '{}',    -- mots à rechercher dans le libellé Claude
  alias TEXT[] DEFAULT '{}',        -- variantes orthographiques observées
  code_article_attendu TEXT,

  -- Lien vers catalogues existants (optionnel)
  appro_catalogue_id UUID,

  -- Metadata
  actif BOOLEAN DEFAULT true,
  nb_match_observes INTEGER DEFAULT 0,
  derniere_obs_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by_id UUID,
  created_by_nom TEXT
);

CREATE INDEX IF NOT EXISTS idx_signatures_fournisseur ON public.produits_signatures (LOWER(fournisseur_nom));
CREATE INDEX IF NOT EXISTS idx_signatures_couleur ON public.produits_signatures (couleur_contenant) WHERE couleur_contenant IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_signatures_actif ON public.produits_signatures (actif) WHERE actif = true;

ALTER TABLE public.produits_signatures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS signatures_all ON public.produits_signatures;
CREATE POLICY signatures_all ON public.produits_signatures FOR ALL USING (true) WITH CHECK (true);

COMMENT ON TABLE public.produits_signatures IS 'Catalogue d''identification visuelle pour matching auto des étiquettes scannées (couleur + type contenant + mots-clés).';

-- 2. Enrichir scan_tracabilite pour stocker les indices visuels + le matching
ALTER TABLE public.scan_tracabilite
  ADD COLUMN IF NOT EXISTS couleur_contenant TEXT,
  ADD COLUMN IF NOT EXISTS type_contenant TEXT,
  ADD COLUMN IF NOT EXISTS taille_apparente TEXT,
  ADD COLUMN IF NOT EXISTS signature_id UUID REFERENCES public.produits_signatures(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS signature_score INTEGER,
  ADD COLUMN IF NOT EXISTS signature_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_trac_signature ON public.scan_tracabilite (signature_id) WHERE signature_id IS NOT NULL;

COMMENT ON COLUMN public.scan_tracabilite.couleur_contenant IS 'Indice visuel extrait par Claude Vision (bleu/blanc/transparent/etc.)';
COMMENT ON COLUMN public.scan_tracabilite.type_contenant IS 'Indice visuel : seau/sachet_sous_vide/barquette/carton/etc.';
COMMENT ON COLUMN public.scan_tracabilite.signature_id IS 'Référence vers produits_signatures si matching effectué (auto ou manuel)';
COMMENT ON COLUMN public.scan_tracabilite.signature_score IS 'Score 0-100 du matching (>=70 = auto, 50-69 = à valider, <50 = orphelin)';

-- 3. Seed des 3 produits Weber René confirmés par Eric le 13/05/2026
-- Note : si tu relances ce script, ces INSERT créeront des doublons. Adapte si besoin.
INSERT INTO public.produits_signatures
  (fournisseur_nom, produit_canonique, poids_attendu_kg, unite_attendue,
   couleur_contenant, type_contenant, taille_apparente,
   mots_cles, alias, created_by_nom)
VALUES
  ('Weber Rene choucrouterie', 'Choucroute crue artisanale', 10.0, 'kg',
   'bleu', 'seau', 'grand',
   ARRAY['choucroute', 'choux', 'kraut', 'crue', 'artisanale'],
   ARRAY['Choucroute crue', 'Choucroute artisanale', 'Choucroute', 'Choucroute crue artisanale 10 KG'],
   'Eric Bresler (seed initial)'),

  ('Weber Rene choucrouterie', 'Pomme de terre épluchée d''Alsace', 5.0, 'kg',
   'transparent', 'sachet_sous_vide', 'moyen',
   ARRAY['pomme', 'terre', 'epluchee', 'alsace'],
   ARRAY['Pomme de terre épluchée d''Alsace', 'Pomme de terre Epluchée d''Alsace',
         'Pomme de terre Épluchée d''Alsace', 'Pommes de terre épluchées',
         'Pomme de terre Epluchee d''Alsace', 'Pomme de terre Épluches d''Alsace'],
   'Eric Bresler (seed initial)'),

  ('Weber Rene choucrouterie', 'Pomme de terre lamelles', 5.0, 'kg',
   'transparent', 'sachet_sous_vide', 'moyen',
   ARRAY['pomme', 'terre', 'lamelle'],
   ARRAY['Pomme de terre Lamelle', 'Pommes de terre lamelles', 'PDT lamelles'],
   'Eric Bresler (seed initial)');

-- 4. Vue pratique pour récupérer les scans avec leur signature
CREATE OR REPLACE VIEW public.v_scans_avec_signature AS
SELECT
  s.id as scan_id, s.session_id, s.created_at, s.statut, s.confiance_globale,
  s.storage_path,
  t.produit, t.fabricant, t.poids_net_kg, t.lot, t.dlc, t.code_article,
  t.couleur_contenant, t.type_contenant, t.taille_apparente,
  t.signature_id, t.signature_score, t.signature_at,
  ps.produit_canonique, ps.fournisseur_nom as signature_fournisseur,
  ss.fournisseur_nom as session_fournisseur
FROM public.scans s
LEFT JOIN public.scan_tracabilite t ON t.scan_id = s.id
LEFT JOIN public.produits_signatures ps ON ps.id = t.signature_id
LEFT JOIN public.scan_sessions ss ON ss.id = s.session_id
WHERE s.type_document = 'etiquette_produit';

COMMENT ON VIEW public.v_scans_avec_signature IS 'Vue facilitant l''affichage des scans avec leur signature matchée le cas échéant.';
