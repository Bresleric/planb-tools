-- ============================================================================
-- Module INFORMATION - Journal de l'entreprise
-- Schéma : publications + ciblage + suivi de lecture
-- ============================================================================
-- Convention PLANB : restaurants en France (CCN HCR), pas de référentiel L-GAV.
-- RLS : non activée (cohérent avec le reste du projet, voir audit).
--       Policies prêtes à activer une fois Supabase Auth en place.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Table principale : informations
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS informations (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

    -- Contenu
    titre TEXT NOT NULL CHECK (char_length(titre) BETWEEN 1 AND 200),
    contenu_md TEXT NOT NULL DEFAULT '',  -- markdown léger

    -- Workflow : proposition (par un collaborateur) → publiee (par admin) → archivee
    statut TEXT NOT NULL DEFAULT 'proposition'
        CHECK (statut IN ('proposition', 'publiee', 'archivee', 'rejetee')),

    -- Ciblage
    --   entreprise      : tous les users actifs (ciblage_value = NULL)
    --   etablissement   : users.etablissement = ciblage_value (ex: 'freddy', 'liesel')
    --   equipe          : users.equipe = ciblage_value (ex: 'cuisine', 'salle')
    --   collaborateurs  : join sur information_targets (sélection manuelle)
    ciblage_type TEXT NOT NULL DEFAULT 'entreprise'
        CHECK (ciblage_type IN ('entreprise', 'etablissement', 'equipe', 'collaborateurs')),
    ciblage_value TEXT,  -- NULL pour entreprise et collaborateurs

    -- Options
    requiert_accuse BOOLEAN NOT NULL DEFAULT TRUE,
    epinglee BOOLEAN NOT NULL DEFAULT FALSE,

    -- Auteurs
    auteur_id UUID NOT NULL,
    auteur_nom TEXT NOT NULL,
    auteur_initiales TEXT,
    valideur_id UUID,                    -- admin qui a publié (si statut = 'publiee')
    valideur_nom TEXT,
    motif_rejet TEXT,                    -- si statut = 'rejetee'

    -- Dates
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    published_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_info_statut_pub
    ON informations(statut, published_at DESC) WHERE statut = 'publiee';
CREATE INDEX IF NOT EXISTS idx_info_ciblage
    ON informations(ciblage_type, ciblage_value);
CREATE INDEX IF NOT EXISTS idx_info_auteur
    ON informations(auteur_id);
CREATE INDEX IF NOT EXISTS idx_info_epinglee
    ON informations(epinglee, published_at DESC) WHERE epinglee = TRUE AND statut = 'publiee';

-- Trigger updated_at
CREATE OR REPLACE FUNCTION trg_informations_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_informations_updated_at ON informations;
CREATE TRIGGER trg_informations_updated_at
    BEFORE UPDATE ON informations
    FOR EACH ROW EXECUTE FUNCTION trg_informations_updated_at();

-- ----------------------------------------------------------------------------
-- 2. Table de ciblage individuel (mode 'collaborateurs')
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS information_targets (
    information_id UUID NOT NULL REFERENCES informations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_nom TEXT,
    user_initiales TEXT,
    PRIMARY KEY (information_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_info_targets_user ON information_targets(user_id);

-- ----------------------------------------------------------------------------
-- 3. Images inline (Storage public bucket : information-images)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS information_images (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    information_id UUID NOT NULL REFERENCES informations(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,         -- chemin dans le bucket information-images
    public_url TEXT,                    -- URL publique cachée (peut être recalculée)
    legende TEXT,
    ordre INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_info_images_info ON information_images(information_id, ordre);

-- ----------------------------------------------------------------------------
-- 4. Pièces jointes (Storage privé bucket : information-attachments)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS information_attachments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    information_id UUID NOT NULL REFERENCES informations(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL,         -- chemin dans le bucket information-attachments
    nom_fichier TEXT NOT NULL,
    mime_type TEXT,
    taille_octets BIGINT,
    ordre INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_info_attach_info ON information_attachments(information_id, ordre);

-- ----------------------------------------------------------------------------
-- 5. Suivi de lecture (accusé explicite)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS information_lectures (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    information_id UUID NOT NULL REFERENCES informations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT,
    lu_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (information_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_info_lectures_info ON information_lectures(information_id);
CREATE INDEX IF NOT EXISTS idx_info_lectures_user ON information_lectures(user_id);

-- ----------------------------------------------------------------------------
-- 6. Vue : informations visibles pour un user dans un établissement
--    Renvoie uniquement les publiées non archivées qui ciblent le user.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_informations_visibles AS
SELECT
    i.*,
    (SELECT COUNT(*) FROM information_lectures l WHERE l.information_id = i.id) AS nb_lectures,
    (SELECT COUNT(*) FROM information_images img WHERE img.information_id = i.id) AS nb_images,
    (SELECT COUNT(*) FROM information_attachments a WHERE a.information_id = i.id) AS nb_pieces_jointes
FROM informations i
WHERE i.statut = 'publiee';

-- ----------------------------------------------------------------------------
-- 7. RPC : liste des IDs d'infos visibles pour un user dans un établissement
--    Utilisée pour le badge "non lues" du portail et le filtrage côté client.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION info_visible_ids(
    p_user_id UUID,
    p_etablissement TEXT,
    p_equipe TEXT DEFAULT NULL
) RETURNS TABLE (information_id UUID) AS $$
BEGIN
    RETURN QUERY
    SELECT i.id
    FROM informations i
    WHERE i.statut = 'publiee'
      AND (
            i.ciblage_type = 'entreprise'
         OR (i.ciblage_type = 'etablissement' AND i.ciblage_value = p_etablissement)
         OR (i.ciblage_type = 'equipe'        AND i.ciblage_value = p_equipe)
         OR (i.ciblage_type = 'collaborateurs'
             AND EXISTS (
                 SELECT 1 FROM information_targets t
                 WHERE t.information_id = i.id AND t.user_id = p_user_id
             ))
      );
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- 8. RPC : compteur d'infos non lues pour le badge du portail
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION info_count_non_lues(
    p_user_id UUID,
    p_etablissement TEXT,
    p_equipe TEXT DEFAULT NULL
) RETURNS INT AS $$
DECLARE
    cnt INT;
BEGIN
    SELECT COUNT(*) INTO cnt
    FROM info_visible_ids(p_user_id, p_etablissement, p_equipe) v
    WHERE NOT EXISTS (
        SELECT 1 FROM information_lectures l
        WHERE l.information_id = v.information_id AND l.user_id = p_user_id
    );
    RETURN COALESCE(cnt, 0);
END;
$$ LANGUAGE plpgsql STABLE;

-- ----------------------------------------------------------------------------
-- 9. RPC : marquer une info comme lue (upsert idempotent)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION info_marquer_lue(
    p_information_id UUID,
    p_user_id UUID,
    p_user_nom TEXT,
    p_user_initiales TEXT
) RETURNS VOID AS $$
BEGIN
    INSERT INTO information_lectures (information_id, user_id, user_nom, user_initiales)
    VALUES (p_information_id, p_user_id, p_user_nom, p_user_initiales)
    ON CONFLICT (information_id, user_id) DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ----------------------------------------------------------------------------
-- 10. RPC : statistiques de lecture pour une info (admin)
--     Retourne nb_cibles, nb_lus, taux, et la liste des non-lus.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION info_stats_lecture(p_information_id UUID)
RETURNS TABLE (
    nb_cibles INT,
    nb_lus INT,
    taux_lecture NUMERIC
) AS $$
DECLARE
    v_ciblage_type TEXT;
    v_ciblage_value TEXT;
    v_nb_cibles INT;
    v_nb_lus INT;
BEGIN
    SELECT ciblage_type, ciblage_value
      INTO v_ciblage_type, v_ciblage_value
      FROM informations WHERE id = p_information_id;

    IF v_ciblage_type IS NULL THEN
        RETURN;
    END IF;

    -- Compte les cibles théoriques selon le type
    IF v_ciblage_type = 'entreprise' THEN
        SELECT COUNT(*) INTO v_nb_cibles FROM users WHERE actif = TRUE;
    ELSIF v_ciblage_type = 'etablissement' THEN
        SELECT COUNT(*) INTO v_nb_cibles FROM users
         WHERE actif = TRUE AND etablissement = v_ciblage_value;
    ELSIF v_ciblage_type = 'equipe' THEN
        SELECT COUNT(*) INTO v_nb_cibles FROM users
         WHERE actif = TRUE AND equipe = v_ciblage_value;
    ELSIF v_ciblage_type = 'collaborateurs' THEN
        SELECT COUNT(*) INTO v_nb_cibles FROM information_targets
         WHERE information_id = p_information_id;
    END IF;

    SELECT COUNT(*) INTO v_nb_lus FROM information_lectures
     WHERE information_id = p_information_id;

    nb_cibles := COALESCE(v_nb_cibles, 0);
    nb_lus := COALESCE(v_nb_lus, 0);
    taux_lecture := CASE WHEN nb_cibles > 0
                         THEN ROUND(100.0 * nb_lus / nb_cibles, 1)
                         ELSE 0 END;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- STORAGE BUCKETS - à créer manuellement dans Supabase Studio ou via CLI :
--
--   1. Bucket : information-images
--      - Public : OUI (URL directe pour <img src>)
--      - Limit MIME : image/jpeg, image/png, image/webp, image/gif
--      - Limit taille : 5 MB par fichier
--
--   2. Bucket : information-attachments
--      - Public : NON (signed URLs uniquement)
--      - Limit MIME : application/pdf, image/*, application/vnd.openxmlformats-*
--      - Limit taille : 20 MB par fichier
--
-- Convention de nommage des chemins :
--   information-images/<information_id>/<uuid>.<ext>
--   information-attachments/<information_id>/<uuid>.<ext>
-- ============================================================================

-- ============================================================================
-- RLS - À ACTIVER quand Supabase Auth sera en place (cf. audit critique C2/C3)
-- ============================================================================
-- ALTER TABLE informations             ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE information_targets      ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE information_images       ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE information_attachments  ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE information_lectures     ENABLE ROW LEVEL SECURITY;
--
-- Exemples de policies à adapter :
--   CREATE POLICY info_select_published ON informations FOR SELECT
--     USING (statut = 'publiee');
--   CREATE POLICY info_insert_self ON informations FOR INSERT
--     WITH CHECK (auteur_id = auth.uid());
--   CREATE POLICY info_update_admin ON informations FOR UPDATE
--     USING (EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND role = 'admin'));
--   CREATE POLICY lectures_self ON information_lectures FOR ALL
--     USING (user_id = auth.uid());
-- ============================================================================
