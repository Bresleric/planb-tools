-- ============================================================
-- PRODUCTION MODULE - Actions post-production (sous-produits & actions induites)
-- À exécuter dans Supabase SQL Editor APRÈS schema-phase3.sql
-- 13 mai 2026
-- ------------------------------------------------------------
-- Objectif : permettre d'attacher à une fiche technique une liste
-- d'actions à effectuer SYSTÉMATIQUEMENT à la fin d'une production
-- de cette fiche (réserver épluchures, parures, refroidir, etc.).
-- À la validation d'une production, une checklist OBLIGATOIRE
-- est présentée à l'exécutant : chaque ligne doit être marquée
-- "Fait" ou "Sauté + raison" avant de pouvoir valider.
-- ============================================================

-- 1. Table fiches_techniques_actions_post
-- Définition des actions complémentaires attachées à une fiche
CREATE TABLE IF NOT EXISTS fiches_techniques_actions_post (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiche_id UUID NOT NULL REFERENCES fiches_techniques(id) ON DELETE CASCADE,

  -- Type d'action : sous-produit à réserver vs action technique
  type TEXT NOT NULL DEFAULT 'sous_produit'
    CHECK (type IN ('sous_produit', 'action')),

  -- Contenu
  libelle TEXT NOT NULL,                  -- ex: "Réserver épluchures asperges"
  instructions TEXT,                       -- détail/consigne pour l'exécutant

  -- Affichage
  position INTEGER DEFAULT 0,              -- ordre dans la checklist
  actif BOOLEAN DEFAULT true,              -- soft-delete

  -- Audit
  cree_par_id UUID,
  cree_par_nom TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ftap_fiche ON fiches_techniques_actions_post(fiche_id);
CREATE INDEX IF NOT EXISTS idx_ftap_actif ON fiches_techniques_actions_post(fiche_id, actif);

ALTER TABLE fiches_techniques_actions_post ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ftap_anon_all" ON fiches_techniques_actions_post;
CREATE POLICY "ftap_anon_all" ON fiches_techniques_actions_post
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- 2. Table productions_actions_post_log
-- Trace de ce qui a été coché/sauté lors d'une production donnée
CREATE TABLE IF NOT EXISTS productions_actions_post_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_id UUID NOT NULL REFERENCES productions(id) ON DELETE CASCADE,

  -- Lien vers l'action originale (SET NULL si supprimée pour préserver l'historique)
  action_post_id UUID REFERENCES fiches_techniques_actions_post(id) ON DELETE SET NULL,

  -- Snapshot du libellé au moment de la production (cas où l'action est supprimée/renommée plus tard)
  libelle_snapshot TEXT NOT NULL,
  type_snapshot TEXT,

  -- Décision de l'exécutant
  statut TEXT NOT NULL CHECK (statut IN ('fait', 'saute')),
  raison_saut TEXT,                         -- requis si statut = 'saute'

  -- Qui a coché
  user_id UUID,
  user_nom TEXT,
  user_initiales TEXT,

  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_papl_production ON productions_actions_post_log(production_id);
CREATE INDEX IF NOT EXISTS idx_papl_action ON productions_actions_post_log(action_post_id);
CREATE INDEX IF NOT EXISTS idx_papl_statut ON productions_actions_post_log(statut);
CREATE INDEX IF NOT EXISTS idx_papl_etablissement ON productions_actions_post_log(etablissement);
CREATE INDEX IF NOT EXISTS idx_papl_date ON productions_actions_post_log(created_at);

ALTER TABLE productions_actions_post_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "papl_anon_all" ON productions_actions_post_log;
CREATE POLICY "papl_anon_all" ON productions_actions_post_log
  FOR ALL TO anon USING (true) WITH CHECK (true);

-- 3. Trigger updated_at sur fiches_techniques_actions_post
CREATE OR REPLACE FUNCTION ftap_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ftap_updated_at ON fiches_techniques_actions_post;
CREATE TRIGGER trg_ftap_updated_at
  BEFORE UPDATE ON fiches_techniques_actions_post
  FOR EACH ROW EXECUTE FUNCTION ftap_set_updated_at();

-- 4. Vérification
SELECT 'fiches_techniques_actions_post créée' AS info,
       COUNT(*) AS lignes FROM fiches_techniques_actions_post;
SELECT 'productions_actions_post_log créée' AS info,
       COUNT(*) AS lignes FROM productions_actions_post_log;
