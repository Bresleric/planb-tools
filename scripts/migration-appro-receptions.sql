-- ============================================
-- Module Approvisionnement — Receptions (Phase 1)
-- PlanB Tools — 06/06/2026
-- ============================================
-- NB : le SQL fourni dans la consigne utilisait BIGSERIAL/BIGINT, mais toutes les
-- cles du module appro sont des uuid. Types corriges en uuid + colonnes ASCII
-- (qte_livree, scan_tracabilite_id) au lieu des accents.
-- Deja applique en base le 06/06/2026 (migration appro_receptions_create). Idempotent.
-- ============================================

CREATE TABLE IF NOT EXISTS appro_receptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  commande_id uuid REFERENCES appro_commandes(id),
  fournisseur_id uuid REFERENCES appro_fournisseurs(id),
  fournisseur_nom text,
  bl_numero text,
  date_reception date DEFAULT CURRENT_DATE,
  etablissement text NOT NULL,
  recu_par_id uuid,
  recu_par_nom text,
  statut text DEFAULT 'en_cours',   -- en_cours, acceptee, annulee
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appro_receptions_etab ON appro_receptions(etablissement, statut);

CREATE TABLE IF NOT EXISTS appro_reception_articles (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  reception_id uuid NOT NULL REFERENCES appro_receptions(id) ON DELETE CASCADE,
  ingredient_id uuid REFERENCES appro_ingredients(id),
  ingredient_nom text,
  categorie_flux text,              -- 'scan' ou 'validation' (copie au moment de la reception)
  qte_commandee numeric,
  qte_livree numeric,
  unite text,
  dlc date,
  aspect_ok boolean,
  photo_url text,
  scan_tracabilite_id uuid,         -- rempli en Phase 2 (flux scan)
  lot text,
  notes text,
  created_at timestamptz DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_appro_reception_articles_rec ON appro_reception_articles(reception_id);

-- RLS (regle PBT : ENABLE + policy permissive anon)
ALTER TABLE appro_receptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS appro_receptions_anon_all ON appro_receptions;
CREATE POLICY appro_receptions_anon_all ON appro_receptions AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE appro_reception_articles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS appro_reception_articles_anon_all ON appro_reception_articles;
CREATE POLICY appro_reception_articles_anon_all ON appro_reception_articles AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Verif :
--   SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'appro_reception%';
