-- ============================================================================
-- Migration : table briefing_archives (journal des infos archivees du briefing)
-- Chantier : archivage des infos persistantes du briefing (managers/admin)
-- Idempotente : rejouable sans risque.
-- Regle PBT (CLAUDE.md par. 8) : toute nouvelle table = RLS + policy anon,
-- sinon lectures vides silencieuses et INSERT bloques pour le role anon.
-- ============================================================================

CREATE TABLE IF NOT EXISTS briefing_archives (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    etablissement   TEXT NOT NULL,
    briefing_date   DATE,
    section         TEXT NOT NULL,          -- produits_limites | produits_dates_courtes | incidents | rappels
    libelle         TEXT NOT NULL,          -- texte principal de la ligne archivee
    contenu         JSONB,                  -- copie complete de la ligne au moment de l archivage
    commentaire     TEXT NOT NULL,          -- motif obligatoire saisi par le manager
    source_table    TEXT,                   -- briefing_incidents | briefing_rappels | NULL
    archive_par_id  UUID,
    archive_par_nom TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index de consultation : par etablissement et date d archivage
CREATE INDEX IF NOT EXISTS idx_briefing_archives_etab_date
    ON briefing_archives (etablissement, created_at DESC);

-- RLS + policy permissive anon (meme pattern que fiche_ingredients)
ALTER TABLE briefing_archives ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_archives_anon_all ON briefing_archives;  -- CREATE POLICY IF NOT EXISTS n existe pas en Postgres
CREATE POLICY briefing_archives_anon_all ON briefing_archives
    AS PERMISSIVE FOR ALL TO anon
    USING (true) WITH CHECK (true);

-- Verification post-migration attendue : 1 ligne avec la policy
-- SELECT tablename, policyname FROM pg_policies WHERE tablename = 'briefing_archives';
