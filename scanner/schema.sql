-- =============================================================================
-- Module Scanner — Phase 0 setup
-- 3 tables (scans, scan_lignes, scan_tracabilite) + bucket Storage `scans` privé
-- Convention PlanB-Tools : RLS active mais policy permissive public_all
-- =============================================================================
-- Date : 2026-04-30
-- Auteur : Eric Bresler (PLANB SARL) avec assistance Cowork

-- =========================================================================
-- TABLE 1 : scans (tronc commun pour tout document scanné)
-- =========================================================================
CREATE TABLE public.scans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  etablissement TEXT NOT NULL,

  -- Type et provenance
  type_document TEXT NOT NULL CHECK (type_document IN ('bl_facture', 'etiquette_produit', 'ticket_caisse', 'autre')),
  voie_capture TEXT NOT NULL CHECK (voie_capture IN ('camera_inapp', 'pdf_scanner_pro', 'email_inbox')),

  -- Stockage du fichier original
  storage_path TEXT NOT NULL,
  nb_pages INTEGER NOT NULL DEFAULT 1 CHECK (nb_pages > 0),
  taille_octets BIGINT,
  mime_type TEXT,
  hash_sha256 TEXT,

  -- Statut du pipeline
  statut TEXT NOT NULL DEFAULT 'en_attente_extraction'
    CHECK (statut IN ('en_attente_extraction', 'extraction_en_cours', 'extrait', 'en_attente_validation', 'valide', 'rejete', 'erreur')),

  -- Résultats Claude Vision
  claude_model TEXT,
  claude_extraction_jsonb JSONB,
  claude_tokens_in INTEGER,
  claude_tokens_out INTEGER,
  claude_cost_usd NUMERIC(8, 5),
  claude_at TIMESTAMPTZ,
  claude_erreur_message TEXT,

  -- Confiance et observations
  confiance_globale INTEGER CHECK (confiance_globale BETWEEN 0 AND 100),
  observation TEXT,

  -- Validation humaine
  valide_par_id UUID,
  valide_par_nom TEXT,
  date_validation TIMESTAMPTZ,

  -- Création
  created_by_id UUID NOT NULL,
  created_by_nom TEXT NOT NULL,
  created_by_initiales TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.scans IS 'Module Scanner : documents scannés (étiquettes, BL, factures, tickets) extraits par Claude Vision';
COMMENT ON COLUMN public.scans.hash_sha256 IS 'Hash du fichier original pour détection automatique des doublons';
COMMENT ON COLUMN public.scans.claude_extraction_jsonb IS 'Sortie brute JSON de Claude Vision avant éclatement dans scan_lignes/scan_tracabilite';

-- Indexes scans
CREATE INDEX idx_scans_etablissement_created ON public.scans (etablissement, created_at DESC);
CREATE INDEX idx_scans_type_statut ON public.scans (type_document, statut);
CREATE UNIQUE INDEX idx_scans_hash_unique ON public.scans (hash_sha256) WHERE hash_sha256 IS NOT NULL;
CREATE INDEX idx_scans_a_traiter ON public.scans (statut, created_at) WHERE statut IN ('en_attente_validation', 'erreur', 'en_attente_extraction');
CREATE INDEX idx_scans_jsonb_gin ON public.scans USING GIN (claude_extraction_jsonb);

-- RLS scans
ALTER TABLE public.scans ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all_scans ON public.scans FOR ALL TO public USING (true) WITH CHECK (true);

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.scans_set_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_scans_updated_at
  BEFORE UPDATE ON public.scans
  FOR EACH ROW EXECUTE FUNCTION public.scans_set_updated_at();


-- =========================================================================
-- TABLE 2 : scan_lignes (lignes BL/facture)
-- =========================================================================
CREATE TABLE public.scan_lignes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,
  ligne_num INTEGER NOT NULL,

  designation TEXT,
  code_article TEXT,
  quantite NUMERIC(12, 4),
  unite TEXT,
  prix_unitaire_ht NUMERIC(12, 4),
  montant_ht NUMERIC(12, 2),
  taux_tva NUMERIC(5, 2),
  montant_tva NUMERIC(12, 2),
  montant_ttc NUMERIC(12, 2),

  -- Lot/DLC quand BL liste lots par ligne
  lot TEXT,
  dlc DATE,

  confiance INTEGER CHECK (confiance BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (scan_id, ligne_num)
);

COMMENT ON TABLE public.scan_lignes IS 'Lignes détaillées des BL/factures extraites par Claude Vision';

CREATE INDEX idx_scan_lignes_scan ON public.scan_lignes (scan_id, ligne_num);

ALTER TABLE public.scan_lignes ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all_scan_lignes ON public.scan_lignes FOR ALL TO public USING (true) WITH CHECK (true);


-- =========================================================================
-- TABLE 3 : scan_tracabilite (HACCP étiquettes)
-- =========================================================================
CREATE TABLE public.scan_tracabilite (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_id UUID NOT NULL REFERENCES public.scans(id) ON DELETE CASCADE,

  -- Identification produit
  produit TEXT,
  code_article TEXT,
  categorie TEXT,
  fabricant TEXT,
  estampille TEXT,
  code_barres TEXT,

  -- Lot et dates
  lot TEXT,
  dlc DATE,
  ddm DATE,
  date_fabrication DATE,
  date_emballage DATE,
  date_abattage DATE,

  -- Poids et températures
  poids_net_kg NUMERIC(8, 3),
  tare_kg NUMERIC(8, 3),
  temp_min NUMERIC(5, 2),
  temp_max NUMERIC(5, 2),

  -- Composition
  ingredients TEXT,
  allergenes TEXT[],
  nutrition JSONB,
  origine TEXT,

  -- Traçabilité bovine (5 colonnes du POC : naissance / élevage / abattage / découpe / pays)
  tracabilite_bovine_jsonb JSONB,

  confiance INTEGER CHECK (confiance BETWEEN 0 AND 100),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.scan_tracabilite IS 'Détail HACCP pour étiquettes produit (héritage du schéma etiquettes_data, enrichi pour Claude Vision)';

CREATE INDEX idx_scan_tracabilite_scan ON public.scan_tracabilite (scan_id);
CREATE INDEX idx_scan_tracabilite_dlc ON public.scan_tracabilite (dlc) WHERE dlc IS NOT NULL;
CREATE INDEX idx_scan_tracabilite_lot ON public.scan_tracabilite (lot) WHERE lot IS NOT NULL;

ALTER TABLE public.scan_tracabilite ENABLE ROW LEVEL SECURITY;
CREATE POLICY public_all_scan_tracabilite ON public.scan_tracabilite FOR ALL TO public USING (true) WITH CHECK (true);


-- =========================================================================
-- BUCKET STORAGE : scans (privé)
-- =========================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'scans',
  'scans',
  false,                              -- privé : pas d'accès public direct
  20971520,                           -- 20 Mo max par fichier
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Policies bucket scans (cohérent avec la convention public_all des tables)
-- Lecture : autorisée (chemins en UUID non devinables)
CREATE POLICY scans_bucket_read ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'scans');

-- Upload : autorisé (l'app gère qui peut uploader via auth maison)
CREATE POLICY scans_bucket_insert ON storage.objects
  FOR INSERT TO public
  WITH CHECK (bucket_id = 'scans');

-- Update / Delete : interdit en direct, on passe par la service_role (Edge Function)
CREATE POLICY scans_bucket_update ON storage.objects
  FOR UPDATE TO public
  USING (bucket_id = 'scans' AND auth.role() = 'service_role');

CREATE POLICY scans_bucket_delete ON storage.objects
  FOR DELETE TO public
  USING (bucket_id = 'scans' AND auth.role() = 'service_role');
