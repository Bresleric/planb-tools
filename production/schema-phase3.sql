-- ============================================================
-- PRODUCTION MODULE - PHASE 3 : Étiquettes & DLC
-- À exécuter dans Supabase SQL Editor APRÈS schema-phase2.sql
-- ============================================================

-- 1. Table dlc_suivi — historique des actions sur les DLC
CREATE TABLE IF NOT EXISTS dlc_suivi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id UUID NOT NULL REFERENCES productions(id) ON DELETE CASCADE,
  action TEXT NOT NULL CHECK (action IN ('controle', 'prolongation', 'consomme', 'jete', 'alerte')),
  ancienne_dlc TIMESTAMPTZ,
  nouvelle_dlc TIMESTAMPTZ,
  motif TEXT,
  user_id UUID NOT NULL,
  user_nom TEXT NOT NULL,
  user_initiales TEXT,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index
CREATE INDEX IF NOT EXISTS idx_dlc_production ON dlc_suivi(production_id);
CREATE INDEX IF NOT EXISTS idx_dlc_etablissement ON dlc_suivi(etablissement);
CREATE INDEX IF NOT EXISTS idx_dlc_action ON dlc_suivi(action);
CREATE INDEX IF NOT EXISTS idx_dlc_date ON dlc_suivi(created_at);

-- RLS
ALTER TABLE dlc_suivi ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "dlc_suivi_anon_all" ON dlc_suivi;
CREATE POLICY "dlc_suivi_anon_all" ON dlc_suivi FOR ALL TO anon USING (true) WITH CHECK (true);

-- 2. Ajout colonne etiquette_imprimee sur productions
ALTER TABLE productions ADD COLUMN IF NOT EXISTS etiquette_imprimee BOOLEAN DEFAULT false;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS etiquette_date TIMESTAMPTZ;

-- 3. Vérification
SELECT 'dlc_suivi créée' AS info, COUNT(*) AS lignes FROM dlc_suivi;
SELECT 'productions avec etiquette' AS info, COUNT(*) FROM information_schema.columns
WHERE table_name = 'productions' AND column_name = 'etiquette_imprimee';
