-- ============================================================================
-- Migration : Sous-module "Etiquettes & rapprochement stock" (module Production)
-- Date : 2026-06-05
-- Idempotente. RLS anon FOR ALL sur chaque nouvelle table (regle PBT CLAUDE.md S8).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. production_rapprochements
--    Une ligne par (etiquette prod -> lot receptionne rapproche).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS production_rapprochements (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id        uuid NOT NULL REFERENCES productions(id) ON DELETE CASCADE,
  tache_id             uuid,
  fiche_ingredient_id  uuid,
  cle_etiquette        text NOT NULL,            -- 'principal' ou 'supp:0', 'supp:1'...
  scan_prod_id         uuid,                     -- etiquette prod (scan_tracabilite.id)
  lot_recu_scan_id     uuid,                     -- lot receptionne (scan_tracabilite.id)
  statut               text NOT NULL DEFAULT 'suggere',  -- suggere | valide | annule
  score_match          integer,
  methode_match        text,                     -- empreinte_dlc_poids | lot_exact | lot_fuzzy | apprentissage | manuel
  quantite_sortie      numeric,
  unite                text DEFAULT 'kg',
  stock_mouvement_id   uuid,
  etablissement        text,
  valide_par_id        uuid,
  valide_par_nom       text,
  valide_par_initiales text,
  valide_at            timestamptz,
  created_at           timestamptz DEFAULT now(),
  updated_at           timestamptz DEFAULT now()
);

ALTER TABLE production_rapprochements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS production_rapprochements_anon_all ON production_rapprochements;
CREATE POLICY production_rapprochements_anon_all ON production_rapprochements
  AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_prod_rappr_production ON production_rapprochements(production_id);
CREATE INDEX IF NOT EXISTS idx_prod_rappr_lot_recu   ON production_rapprochements(lot_recu_scan_id);

-- ----------------------------------------------------------------------------
-- 2. rapprochement_apprentissage
--    Brique d'apprentissage : mapping (article, lot OCR normalise) -> lot recu.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rapprochement_apprentissage (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  article_id        uuid,
  lot_ocr_normalise text,
  lot_recu          text,
  lot_recu_scan_id  uuid,
  nb_confirmations  integer DEFAULT 0,
  nb_rejets         integer DEFAULT 0,
  derniere_decision text,                        -- valide | rejete
  etablissement     text,
  created_by_id     uuid,
  created_by_nom    text,
  created_at        timestamptz DEFAULT now(),
  updated_at        timestamptz DEFAULT now()
);

ALTER TABLE rapprochement_apprentissage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rapprochement_apprentissage_anon_all ON rapprochement_apprentissage;
CREATE POLICY rapprochement_apprentissage_anon_all ON rapprochement_apprentissage
  AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Unicite (article, lot normalise, etablissement) pour upsert ON CONFLICT.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_rappr_appr_article_lot_etab
  ON rapprochement_apprentissage(article_id, lot_ocr_normalise, etablissement);

-- ----------------------------------------------------------------------------
-- 3. Colonnes d'audit reouverture sur productions
-- ----------------------------------------------------------------------------
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_par_id    uuid;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_par_nom   text;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouvert_at        timestamptz;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS rouverture_motif  text;
ALTER TABLE productions ADD COLUMN IF NOT EXISTS nb_reouvertures   integer DEFAULT 0;

-- ----------------------------------------------------------------------------
-- Verif post-migration :
--   SELECT tablename, policyname FROM pg_policies
--   WHERE tablename IN ('production_rapprochements','rapprochement_apprentissage');
-- ----------------------------------------------------------------------------
