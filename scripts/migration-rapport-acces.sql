-- ============================================================================
-- Migration : acces au rapport journalier par lien magique
-- (appliquee via MCP le 30/09/2026, gardee pour trace)
-- Un token = un lien personnel du type rapport/?k=<token>, revocable en
-- passant actif=false. Les tokens eux-memes ne sont JAMAIS commites ici
-- (repo public) : ils sont inseres a la main ou via Claude directement en base.
-- ============================================================================

CREATE TABLE IF NOT EXISTS rapport_acces (
    token       TEXT PRIMARY KEY,
    nom         TEXT NOT NULL,
    actif       BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE rapport_acces ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS rapport_acces_anon_all ON rapport_acces;
CREATE POLICY rapport_acces_anon_all ON rapport_acces
    AS PERMISSIVE FOR ALL TO anon
    USING (true) WITH CHECK (true);

-- Exemple de creation d un nouveau lien (token a generer aleatoirement, long) :
-- INSERT INTO rapport_acces (token, nom) VALUES ('<48 caracteres hexa>', 'Prenom (appareil)');
-- Revocation : UPDATE rapport_acces SET actif = false WHERE nom = '...';
