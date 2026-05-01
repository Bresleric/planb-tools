-- =============================================================================
-- Module Scanner — Phase 3 setup
-- Table scan_sessions (réception groupée) + session_id sur scans
-- =============================================================================
-- Date : 2026-04-30
-- Convention PlanB-Tools : RLS active mais policy permissive public_all

-- =========================================================================
-- TABLE : scan_sessions
-- 1 session = 1 réception (1 fournisseur, N étiquettes + 1 BL/facture)
-- =========================================================================
CREATE TABLE public.scan_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  etablissement TEXT NOT NULL,

  -- Fournisseur
  fournisseur_id UUID REFERENCES public.appro_fournisseurs(id) ON DELETE SET NULL,
  fournisseur_nom TEXT NOT NULL,

  -- Métadonnées
  date_reception DATE NOT NULL DEFAULT CURRENT_DATE,
  commentaire TEXT,

  -- Statut du flux
  statut TEXT NOT NULL DEFAULT 'en_cours'
    CHECK (statut IN (
      'en_cours',                -- l'utilisateur scanne les étiquettes
      'etiquettes_terminees',    -- toutes les étiquettes scannées, attente BL
      'bl_scanne',               -- BL ajouté, prêt pour rapprochement
      'rapprochement_en_cours',  -- appel reconcile-session en cours
      'rapprochee',              -- rapprochement fait, attente validation humaine
      'validee',                 -- validation finale par l'utilisateur
      'rejetee'                  -- session abandonnée/refusée
    )),

  -- Compteurs (mis à jour par l'app à chaque ajout)
  nb_etiquettes INTEGER NOT NULL DEFAULT 0,
  nb_etiquettes_extraites INTEGER NOT NULL DEFAULT 0,

  -- Lien vers le scan du BL/facture
  bl_facture_scan_id UUID REFERENCES public.scans(id) ON DELETE SET NULL,

  -- Résultat du rapprochement Claude
  rapprochement_jsonb JSONB,
  rapprochement_at TIMESTAMPTZ,
  rapprochement_anomalies_count INTEGER DEFAULT 0,
  rapprochement_tokens_in INTEGER,
  rapprochement_tokens_out INTEGER,
  rapprochement_cost_usd NUMERIC(8, 5),

  -- Validation finale
  validee_par_id UUID,
  validee_par_nom TEXT,
  date_validation TIMESTAMPTZ,
  observation_validation TEXT,

  -- Création
  created_by_id UUID NOT NULL,
  created_by_nom TEXT NOT NULL,
  created_by_initiales TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  cloturee_at TIMESTAMPTZ
);

COMMENT ON TABLE public.scan_sessions IS 'Module Scanner : sessions de réception groupée (1 fournisseur, N étiquettes + 1 BL/facture, rapprochement automatique)';
COMMENT ON COLUMN public.scan_sessions.rapprochement_jsonb IS 'Résultat du rapprochement Claude : structure { matchs: [...], anomalies: [...], totaux: {...} }';

-- Indexes
CREATE INDEX idx_scan_sessions_etablissement_date ON public.scan_sessions (etablissement, date_reception DESC);
CREATE INDEX idx_scan_sessions_statut ON public.scan_sessions (statut, created_at) WHERE statut NOT IN ('validee', 'rejetee');
CREATE INDEX idx_scan_sessions_fournisseur ON public.scan_sessions (fournisseur_id) WHERE fournisseur_id IS NOT NULL;

-- RLS
ALTER TABLE public.scan_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all_scan_sessions ON public.scan_sessions FOR ALL TO public USING (true) WITH CHECK (true);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.scan_sessions_set_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_scan_sessions_updated_at
  BEFORE UPDATE ON public.scan_sessions
  FOR EACH ROW EXECUTE FUNCTION public.scan_sessions_set_updated_at();


-- =========================================================================
-- ALTER scans : ajout de session_id
-- =========================================================================
ALTER TABLE public.scans
  ADD COLUMN session_id UUID REFERENCES public.scan_sessions(id) ON DELETE SET NULL;

CREATE INDEX idx_scans_session ON public.scans (session_id) WHERE session_id IS NOT NULL;

COMMENT ON COLUMN public.scans.session_id IS 'Lien optionnel vers une scan_sessions (mode réception groupée). NULL = scan unitaire.';
