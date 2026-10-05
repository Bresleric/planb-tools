-- ============================================================================
-- Migration : commandes de produits intermediaires entre etablissements
-- A executer dans Supabase SQL Editor si le canal MCP est gele - idempotente.
-- ============================================================================
CREATE TABLE IF NOT EXISTS interetab_produits (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom         TEXT NOT NULL,
    unite       TEXT NOT NULL DEFAULT 'kg',
    ordre       SMALLINT NOT NULL DEFAULT 0,
    actif       BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS interetab_commandes (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    demandeur_etab   TEXT NOT NULL,
    fournisseur_etab TEXT NOT NULL,
    statut           TEXT NOT NULL DEFAULT 'demande',
    lignes           JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes            TEXT,
    date_souhaitee   DATE,
    demande_par_id   UUID, demande_par_nom TEXT,
    validee_par_id   UUID, validee_par_nom TEXT, validee_at TIMESTAMPTZ,
    prete_par_id     UUID, prete_par_nom TEXT, prete_at TIMESTAMPTZ,
    recuperee_par_id UUID, recuperee_par_nom TEXT, recuperee_at TIMESTAMPTZ,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_interetab_commandes_statut
    ON interetab_commandes (statut, created_at DESC);

ALTER TABLE interetab_produits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS interetab_produits_anon_all ON interetab_produits;
CREATE POLICY interetab_produits_anon_all ON interetab_produits
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE interetab_commandes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS interetab_commandes_anon_all ON interetab_commandes;
CREATE POLICY interetab_commandes_anon_all ON interetab_commandes
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

INSERT INTO interetab_produits (nom, unite, ordre)
SELECT v.nom, v.unite, v.ordre FROM (VALUES
    ('Spaetzele', 'kg', 1),
    ('Pommes épluchées et taillées', 'kg', 2),
    ('Oignons émincés', 'kg', 3),
    ('Légumes épluchés', 'kg', 4),
    ('Salade lavée', 'kg', 5)
) AS v(nom, unite, ordre)
WHERE NOT EXISTS (SELECT 1 FROM interetab_produits);

-- Verification attendue : 2 lignes
-- SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'interetab%';
