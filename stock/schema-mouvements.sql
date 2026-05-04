-- =============================================================================
-- Module Stock — Lot 1 : Mouvements de stock
-- =============================================================================
-- Date : 2026-05-04
-- Convention PlanB-Tools : RLS active mais policy permissive public_all
--
-- Crée la table stock_mouvements (ENTREE / SORTIE / AJUSTEMENT par lot précis),
-- le trigger qui crée automatiquement une ENTREE quand un scan se voit rattaché
-- à un article, le backfill rétroactif pour les scans déjà rattachés, et la vue
-- stock_par_lot qui calcule en temps réel la quantité restante par lot.

-- =========================================================================
-- TABLE : stock_mouvements
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.stock_mouvements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL CHECK (type IN ('ENTREE', 'SORTIE', 'AJUSTEMENT')),

  -- Article et lot
  article_id UUID NOT NULL REFERENCES public.appro_ingredients(id) ON DELETE RESTRICT,
  scan_tracabilite_id UUID REFERENCES public.scan_tracabilite(id) ON DELETE SET NULL,

  -- Quantité (toujours positive ; le signe est porté par le `type`)
  -- AJUSTEMENT peut être positif (correction +) ou négatif (correction -) → on autorise négatif
  quantite NUMERIC(10, 3) NOT NULL,
  unite TEXT,

  -- Localisation
  etablissement TEXT NOT NULL,

  -- Traçabilité
  motif TEXT,
  source_table TEXT,    -- 'scan_tracabilite' | 'production' | 'sortie_manuelle' | 'inventaire' | 'ajustement_manuel'
  source_id UUID,       -- id dans la source_table

  -- Création
  created_by_id UUID NOT NULL,
  created_by_nom TEXT NOT NULL,
  created_by_initiales TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.stock_mouvements IS 'Module Stock : journal des mouvements de stock par lot. Source de vérité pour calculer le stock courant.';
COMMENT ON COLUMN public.stock_mouvements.scan_tracabilite_id IS 'Lien vers le lot précis (scan_tracabilite). NULL si entrée non-scannée ou ajustement global article.';
COMMENT ON COLUMN public.stock_mouvements.quantite IS 'Quantité positive pour ENTREE/SORTIE. Pour AJUSTEMENT, peut être positive (correction +) ou négative (correction -).';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_article ON public.stock_mouvements (article_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_lot ON public.stock_mouvements (scan_tracabilite_id) WHERE scan_tracabilite_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_etab ON public.stock_mouvements (etablissement, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_type ON public.stock_mouvements (type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stock_mouvements_source ON public.stock_mouvements (source_table, source_id);

-- RLS
ALTER TABLE public.stock_mouvements ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY public_all_stock_mouvements ON public.stock_mouvements FOR ALL TO public USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- =========================================================================
-- TRIGGER : ENTREE automatique quand un scan_tracabilite gagne un article_id
-- =========================================================================
CREATE OR REPLACE FUNCTION public.create_entree_from_scan_match() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_etab text;
  v_existing int;
BEGIN
  -- Conditions de déclenchement :
  -- INSERT avec article_id NOT NULL → entrée
  -- UPDATE qui passe article_id de NULL à NOT NULL → entrée
  -- UPDATE qui change article_id (de NOT NULL à NOT NULL différent) → on ne crée PAS de mouvement
  --   (le rattachement reste, juste l'article cible change ; un AJUSTEMENT manuel peut être fait par l'admin si besoin)

  IF NOT (
    (TG_OP = 'INSERT' AND NEW.article_id IS NOT NULL)
    OR (TG_OP = 'UPDATE' AND OLD.article_id IS NULL AND NEW.article_id IS NOT NULL)
  ) THEN
    RETURN NEW;
  END IF;

  -- Vérifier si un mouvement ENTREE existe déjà pour ce lot (idempotence)
  SELECT COUNT(*) INTO v_existing FROM public.stock_mouvements
  WHERE scan_tracabilite_id = NEW.id AND type = 'ENTREE';
  IF v_existing > 0 THEN
    RETURN NEW;
  END IF;

  -- Récupérer l'établissement depuis scans
  SELECT etablissement INTO v_etab FROM public.scans WHERE id = NEW.scan_id;
  IF v_etab IS NULL THEN
    -- Pas d'établissement → on n'enregistre pas
    RETURN NEW;
  END IF;

  INSERT INTO public.stock_mouvements (
    type, article_id, scan_tracabilite_id, quantite, unite, etablissement,
    motif, source_table, source_id,
    created_by_id, created_by_nom, created_at
  ) VALUES (
    'ENTREE',
    NEW.article_id,
    NEW.id,
    COALESCE(NEW.poids_net_kg, 0),
    'kg',
    v_etab,
    'Étiquette scannée',
    'scan_tracabilite',
    NEW.id,
    COALESCE(NEW.match_par_id, '00000000-0000-0000-0000-000000000000'::uuid),
    COALESCE(NEW.match_par_nom, 'Système'),
    COALESCE(NEW.match_at, now())
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_scan_tracabilite_entree ON public.scan_tracabilite;
CREATE TRIGGER trg_scan_tracabilite_entree
  AFTER INSERT OR UPDATE OF article_id ON public.scan_tracabilite
  FOR EACH ROW EXECUTE FUNCTION public.create_entree_from_scan_match();


-- =========================================================================
-- BACKFILL : créer les ENTREES rétroactives pour les scans déjà rattachés
-- =========================================================================
INSERT INTO public.stock_mouvements (
  type, article_id, scan_tracabilite_id, quantite, unite, etablissement,
  motif, source_table, source_id,
  created_by_id, created_by_nom, created_at
)
SELECT
  'ENTREE',
  t.article_id,
  t.id,
  COALESCE(t.poids_net_kg, 0),
  'kg',
  s.etablissement,
  'Étiquette scannée (backfill ' || to_char(now(), 'YYYY-MM-DD') || ')',
  'scan_tracabilite',
  t.id,
  COALESCE(t.match_par_id, '00000000-0000-0000-0000-000000000000'::uuid),
  COALESCE(t.match_par_nom, 'Backfill'),
  COALESCE(t.match_at, t.created_at)
FROM public.scan_tracabilite t
JOIN public.scans s ON s.id = t.scan_id
WHERE t.article_id IS NOT NULL
  AND s.statut IN ('valide', 'en_attente_validation', 'extrait')
  AND NOT EXISTS (
    SELECT 1 FROM public.stock_mouvements m
    WHERE m.scan_tracabilite_id = t.id AND m.type = 'ENTREE'
  );


-- =========================================================================
-- VUE : stock_par_lot — quantité restante calculée en temps réel
-- =========================================================================
CREATE OR REPLACE VIEW public.stock_par_lot AS
WITH agg AS (
  SELECT
    scan_tracabilite_id,
    SUM(CASE WHEN type = 'ENTREE'      THEN quantite ELSE 0 END) AS qte_entree,
    SUM(CASE WHEN type = 'SORTIE'      THEN quantite ELSE 0 END) AS qte_sortie,
    SUM(CASE WHEN type = 'AJUSTEMENT'  THEN quantite ELSE 0 END) AS qte_ajustement
  FROM public.stock_mouvements
  WHERE scan_tracabilite_id IS NOT NULL
  GROUP BY scan_tracabilite_id
)
SELECT
  t.id AS scan_tracabilite_id,
  t.article_id,
  a.nom AS article_nom,
  a.categorie AS article_categorie,
  a.unite AS article_unite,
  s.etablissement,
  t.lot,
  t.dlc,
  t.ddm,
  t.fabricant,
  t.origine,
  t.poids_net_kg AS quantite_initiale,
  COALESCE(g.qte_entree, 0)     AS qte_entree,
  COALESCE(g.qte_sortie, 0)     AS qte_sortie,
  COALESCE(g.qte_ajustement, 0) AS qte_ajustement,
  COALESCE(g.qte_entree, 0) - COALESCE(g.qte_sortie, 0) + COALESCE(g.qte_ajustement, 0) AS quantite_restante,
  s.created_at AS scan_at,
  s.created_by_nom AS scan_par
FROM public.scan_tracabilite t
JOIN public.scans s ON s.id = t.scan_id
JOIN public.appro_ingredients a ON a.id = t.article_id
LEFT JOIN agg g ON g.scan_tracabilite_id = t.id
WHERE t.article_id IS NOT NULL
  AND s.statut IN ('valide', 'en_attente_validation', 'extrait');

COMMENT ON VIEW public.stock_par_lot IS 'Stock courant par lot (entrée - sortie + ajustement). Filtré sur scans rattachés à un article et de statut actif.';


-- =========================================================================
-- VUE : stock_par_article — agrégation par article
-- =========================================================================
CREATE OR REPLACE VIEW public.stock_par_article AS
SELECT
  article_id,
  article_nom,
  article_categorie,
  article_unite,
  etablissement,
  COUNT(*) FILTER (WHERE quantite_restante > 0)        AS nb_lots_dispo,
  COUNT(*) FILTER (WHERE quantite_restante <= 0)       AS nb_lots_epuises,
  SUM(quantite_restante)                                AS quantite_restante_total,
  MIN(dlc) FILTER (WHERE quantite_restante > 0)         AS dlc_min_dispo,
  MAX(scan_at)                                          AS dernier_scan_at
FROM public.stock_par_lot
GROUP BY article_id, article_nom, article_categorie, article_unite, etablissement;

COMMENT ON VIEW public.stock_par_article IS 'Agrégation du stock courant par article et par établissement.';
