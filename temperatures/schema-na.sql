-- ============================================================
-- Module Temperatures - Migration "N/A!" (machine en panne, etc.)
-- A executer dans Supabase SQL Editor
-- ============================================================
-- Objectif :
--   Permettre de marquer un appareil comme "Non Applicable" pour la
--   journee (panne, degivrage, debranche, vide, maintenance, autre)
--   sans renseigner de temperature.
--
--   Le releve est compte comme fait (couvre le HACCP : tous les
--   appareils sont traites), mais aucune alerte hors-norme ni
--   re-controle 1h ne sont declenches.
-- ============================================================

-- 1. Rendre la colonne temperature nullable (uniquement pour les N/A)
ALTER TABLE temp_releves
  ALTER COLUMN temperature DROP NOT NULL;

-- 2. Ajouter le statut + motif + commentaire
ALTER TABLE temp_releves
  ADD COLUMN IF NOT EXISTS statut TEXT,            -- NULL = releve normal, 'N_A' = non applicable
  ADD COLUMN IF NOT EXISTS motif_na TEXT,          -- 'PANNE' | 'DEGIVRAGE' | 'DEBRANCHE' | 'VIDE' | 'MAINTENANCE' | 'AUTRE'
  ADD COLUMN IF NOT EXISTS commentaire_na TEXT;    -- texte libre (obligatoire si motif = 'AUTRE')

-- 3. Contrainte de coherence
--   - statut = 'N_A'    -> temperature DOIT etre NULL, motif_na DOIT etre renseigne
--   - statut IS NULL    -> temperature DOIT etre renseignee
ALTER TABLE temp_releves
  DROP CONSTRAINT IF EXISTS temp_releves_statut_coherence;

ALTER TABLE temp_releves
  ADD CONSTRAINT temp_releves_statut_coherence
  CHECK (
    (statut = 'N_A' AND temperature IS NULL AND motif_na IS NOT NULL)
    OR
    (statut IS NULL AND temperature IS NOT NULL)
  );

-- 4. Index pour requetes
CREATE INDEX IF NOT EXISTS idx_temp_releves_statut
  ON temp_releves(statut, date) WHERE statut IS NOT NULL;

-- 5. Verification
-- SELECT column_name, data_type, is_nullable
--   FROM information_schema.columns
--  WHERE table_name = 'temp_releves'
--    AND column_name IN ('temperature','statut','motif_na','commentaire_na')
--  ORDER BY ordinal_position;
