-- ============================================================
-- Migration : Production multi sous-produits (Phase 1)
-- 1 production cuisine -> N etiquettes/contenants en sortie
-- Ex : choucroute garnie -> 5 sous-produits cuits
-- Idempotent : reexecutable sans risque (IF NOT EXISTS partout)
-- ============================================================

-- ------------------------------------------------------------
-- 1) Table de definition des sous-produits d une fiche technique
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fiches_techniques_sous_produits (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fiche_id              UUID NOT NULL REFERENCES fiches_techniques(id) ON DELETE CASCADE,
  ordre                 SMALLINT NOT NULL DEFAULT 0,
  nom                   TEXT NOT NULL,
  -- article catalogue du sous-produit CUIT (nullable, peut etre cree a la volee plus tard)
  article_id            UUID REFERENCES appro_ingredients(id),
  -- article catalogue de la MP CRUE d origine (pre-remplit la quantite a la validation depuis le scan de cette MP)
  source_article_id     UUID REFERENCES appro_ingredients(id),
  -- multiplicateur cru -> cuit : 1 pour lards/choucroute, 2 pour gendarmes coupes en 2
  ratio_transformation  NUMERIC NOT NULL DEFAULT 1,
  -- mise_en_place / produit_intermediaire / produit_fini
  categorie             TEXT,
  -- fallback si pas de source_article_id ou si MP non scannee
  quantite_estimee      NUMERIC,
  -- kg, g, L, cl, piece, portion, sachet, etc.
  unite                 TEXT,
  dlc_jours             INTEGER,
  dlc_heures            INTEGER,
  temperature_stockage  TEXT,
  conditionnement       TEXT,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_ftsp_fiche_nom UNIQUE (fiche_id, nom)
);

CREATE INDEX IF NOT EXISTS idx_ftsp_fiche
  ON fiches_techniques_sous_produits (fiche_id);

CREATE INDEX IF NOT EXISTS idx_ftsp_source
  ON fiches_techniques_sous_produits (source_article_id)
  WHERE source_article_id IS NOT NULL;

-- ------------------------------------------------------------
-- 2) Lien parent -> enfant sur les productions
--    (une production "fille" = un sous-produit issu d une production "mere")
-- ------------------------------------------------------------
ALTER TABLE productions
  ADD COLUMN IF NOT EXISTS parent_production_id UUID
  REFERENCES productions(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_prod_parent
  ON productions (parent_production_id)
  WHERE parent_production_id IS NOT NULL;

-- ------------------------------------------------------------
-- 3) Verification (a lire apres execution)
-- ------------------------------------------------------------
SELECT
  (SELECT COUNT(*) FROM fiches_techniques_sous_produits)                 AS nb_lignes_sous_produits,
  (SELECT COUNT(*) FROM information_schema.columns
     WHERE table_name = 'productions'
       AND column_name = 'parent_production_id')                        AS colonne_parent_production_id_presente;
