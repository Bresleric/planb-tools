-- ============================================================================
-- Caisse : CA pre-rempli depuis L Addition (etape 1) — trace de l origine
-- Idempotent : rejouable sans risque. Pas de nouvelle table -> la policy
-- pbt_session de caisse_controle s applique aux nouvelles colonnes.
--   ca_source       : 'laddition' (CA repris de L Addition) ou 'manuel'
--                     (saisie de secours : synchro indisponible, ou admin)
--   ca_laddition_le : heure de la derniere photo caisse L Addition utilisee
-- Les jours enregistres avant cette version restent a NULL (origine inconnue).
-- ============================================================================
ALTER TABLE caisse_controle ADD COLUMN IF NOT EXISTS ca_source text;
ALTER TABLE caisse_controle ADD COLUMN IF NOT EXISTS ca_laddition_le timestamptz;

-- Verification :
--   SELECT column_name, data_type FROM information_schema.columns
--     WHERE table_name = 'caisse_controle' AND column_name IN ('ca_source', 'ca_laddition_le');
