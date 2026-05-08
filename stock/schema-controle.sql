-- =============================================================================
-- Module Stock — Contrôle Stock Réel
-- =============================================================================
-- Date : 2026-05-08
-- Convention PlanB-Tools : RLS active mais policy permissive public_all
--
-- Crée les tables stock_controle_sessions et stock_controle_lignes pour tracer
-- les sessions de contrôle physique du stock (vérification que les étiquettes
-- en système correspondent à la réalité dans les frigos).

-- =========================================================================
-- TABLE : stock_controle_sessions
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.stock_controle_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Localisation
  etablissement TEXT NOT NULL,

  -- Statut : en_cours / termine / abandonne
  statut TEXT NOT NULL DEFAULT 'en_cours' CHECK (statut IN ('en_cours', 'termine', 'abandonne')),

  -- Compteurs (mis à jour à la finalisation)
  nb_lots_total INT NOT NULL DEFAULT 0,
  nb_ok INT NOT NULL DEFAULT 0,
  nb_pas_ok INT NOT NULL DEFAULT 0,
  nb_sautes INT NOT NULL DEFAULT 0,
  nb_sorties INT NOT NULL DEFAULT 0,

  -- Notes libres (zone de commentaire à la fin)
  notes TEXT,

  -- Création / clôture
  ouvert_par_id UUID NOT NULL,
  ouvert_par_nom TEXT NOT NULL,
  ouvert_par_initiales TEXT,
  date_debut TIMESTAMPTZ NOT NULL DEFAULT now(),
  date_fin TIMESTAMPTZ
);

COMMENT ON TABLE public.stock_controle_sessions IS 'Module Stock : sessions de contrôle physique du stock (vérification réalité vs système).';

CREATE INDEX IF NOT EXISTS idx_stock_controle_sessions_etab ON public.stock_controle_sessions (etablissement, date_debut DESC);
CREATE INDEX IF NOT EXISTS idx_stock_controle_sessions_statut ON public.stock_controle_sessions (statut, date_debut DESC);

ALTER TABLE public.stock_controle_sessions ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY public_all_stock_controle_sessions ON public.stock_controle_sessions FOR ALL TO public USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;


-- =========================================================================
-- TABLE : stock_controle_lignes
-- =========================================================================
CREATE TABLE IF NOT EXISTS public.stock_controle_lignes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Session parente
  session_id UUID NOT NULL REFERENCES public.stock_controle_sessions(id) ON DELETE CASCADE,

  -- Lot contrôlé (snapshot des données au moment du contrôle pour garder la trace même si le lot est supprimé/modifié)
  scan_tracabilite_id UUID REFERENCES public.scan_tracabilite(id) ON DELETE SET NULL,
  article_id UUID REFERENCES public.appro_ingredients(id) ON DELETE SET NULL,
  article_nom_snapshot TEXT,
  produit_snapshot TEXT,
  lot_snapshot TEXT,
  dlc_snapshot DATE,
  quantite_snapshot NUMERIC(10, 3),
  unite_snapshot TEXT,

  -- Résultat du contrôle
  statut TEXT NOT NULL CHECK (statut IN ('OK', 'PAS_OK', 'SAUTE')),
  motif TEXT,                        -- Si PAS_OK : pourquoi (Perte / Casse / Vol / Erreur saisie / Autre + texte libre)

  -- Sortie de stock effectuée si PAS_OK
  sortie_effectuee BOOLEAN NOT NULL DEFAULT false,
  quantite_sortie NUMERIC(10, 3),
  mouvement_id UUID REFERENCES public.stock_mouvements(id) ON DELETE SET NULL,

  -- Auteur du contrôle (peut différer de ouvert_par dans certaines orga)
  controle_par_id UUID NOT NULL,
  controle_par_nom TEXT NOT NULL,
  controle_par_initiales TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.stock_controle_lignes IS 'Module Stock : lignes individuelles de contrôle (1 par lot vérifié) avec snapshot des données.';
COMMENT ON COLUMN public.stock_controle_lignes.statut IS 'OK = présent et conforme / PAS_OK = manquant ou non conforme / SAUTE = ignoré (passé sans contrôle)';

CREATE INDEX IF NOT EXISTS idx_stock_controle_lignes_session ON public.stock_controle_lignes (session_id, created_at);
CREATE INDEX IF NOT EXISTS idx_stock_controle_lignes_scan ON public.stock_controle_lignes (scan_tracabilite_id);
CREATE INDEX IF NOT EXISTS idx_stock_controle_lignes_statut ON public.stock_controle_lignes (statut);

ALTER TABLE public.stock_controle_lignes ENABLE ROW LEVEL SECURITY;
DO $$ BEGIN
  CREATE POLICY public_all_stock_controle_lignes ON public.stock_controle_lignes FOR ALL TO public USING (true) WITH CHECK (true);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;
