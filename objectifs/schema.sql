-- ============================================================
-- MODULE OBJECTIFS DE VENTES
-- Permet de surcharger jour par jour les objectifs calculés auto
-- PlanB Tools - Supabase Migration
-- ============================================================

CREATE TABLE IF NOT EXISTS objectifs_ventes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  date DATE NOT NULL,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),

  -- Objectif en euros TTC
  ca_ttc_objectif NUMERIC(10,2) NOT NULL CHECK (ca_ttc_objectif >= 0),

  -- Référence / contexte
  ca_ttc_n1_aligne NUMERIC(10,2),          -- CA N-1 calé (pour info / audit)
  pct_vs_n1 NUMERIC(5,2),                  -- % utilisé pour calculer (ex: 2.00 ou 5.00)

  -- Source de la valeur
  source TEXT NOT NULL DEFAULT 'auto' CHECK (source IN ('auto', 'manuel', 'import')),
  commentaire TEXT,

  -- Traçabilité
  cree_par_id UUID,
  cree_par_nom TEXT,
  modifie_par_id UUID,
  modifie_par_nom TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Unicité : un seul objectif par date + établissement
  UNIQUE(date, etablissement)
);

-- Index utiles
CREATE INDEX IF NOT EXISTS idx_obj_date ON objectifs_ventes(date);
CREATE INDEX IF NOT EXISTS idx_obj_date_etab ON objectifs_ventes(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_obj_source ON objectifs_ventes(source);

-- RLS (Row Level Security)
ALTER TABLE objectifs_ventes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "obj_anon_all" ON objectifs_ventes FOR ALL TO anon USING (true) WITH CHECK (true);

-- Vérification
SELECT 'Table objectifs_ventes créée' AS info,
  (SELECT COUNT(*) FROM objectifs_ventes) AS nb_objectifs;
