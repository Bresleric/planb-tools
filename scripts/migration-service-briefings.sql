-- Migration: Table service_briefings pour briefings de fin de service
-- Briefings collaboratifs (soir -> matin suivant, matin -> apres-midi)

CREATE TABLE IF NOT EXISTS public.service_briefings (
  id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  etablissement TEXT NOT NULL,
  date_briefing DATE NOT NULL,
  service_type TEXT NOT NULL, -- 'soir' ou 'apres-midi'

  -- 7 sections de contenu (NULL si non remplies)
  livraisons_attendues TEXT,
  produits_dlc TEXT,
  cuissons_nuit TEXT,
  difficultes TEXT,
  points_discuter TEXT,
  equipements_defectueux TEXT,
  equipements_defectueux_photo_base64 TEXT, -- Photo encodee en base64 si equipements remplis
  actions_commencer TEXT,

  created_by TEXT, -- Email ou ID utilisateur qui a cree
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  is_finalized BOOLEAN DEFAULT FALSE,

  CONSTRAINT service_briefings_unique UNIQUE (etablissement, date_briefing, service_type)
);

-- Indexs pour les requetes courantes
CREATE INDEX IF NOT EXISTS idx_service_briefings_etablissement_date
  ON public.service_briefings(etablissement, date_briefing DESC);
CREATE INDEX IF NOT EXISTS idx_service_briefings_etablissement_service
  ON public.service_briefings(etablissement, service_type, date_briefing DESC);

-- Row-Level Security (obligatoire par CLAUDE.md)
ALTER TABLE public.service_briefings ENABLE ROW LEVEL SECURITY;

-- Policy: anon (visiteurs auth) peuvent lire et modifier tout
DROP POLICY IF EXISTS service_briefings_anon_all ON public.service_briefings;
CREATE POLICY service_briefings_anon_all ON public.service_briefings
  AS PERMISSIVE FOR ALL TO anon
  USING (true) WITH CHECK (true);

-- Verif: SELECT tablename, policyname FROM pg_policies WHERE tablename = 'service_briefings';
