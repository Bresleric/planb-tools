-- ============================================================================
-- Migration : cahier de liaison (messages d equipe signes + registre lectures)
-- Idempotente. Regle PBT : RLS + policy anon sur toute nouvelle table.
-- ============================================================================
CREATE TABLE IF NOT EXISTS liaison_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    etablissement   TEXT NOT NULL,
    texte           TEXT NOT NULL,
    auteur_id       UUID NOT NULL,
    auteur_nom      TEXT,
    auteur_initiales TEXT,
    destinataires   JSONB NOT NULL DEFAULT '[]'::jsonb,
    epingle         BOOLEAN NOT NULL DEFAULT false,
    archive         BOOLEAN NOT NULL DEFAULT false,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS liaison_lectures (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id  UUID NOT NULL REFERENCES liaison_messages(id) ON DELETE CASCADE,
    user_id     UUID NOT NULL,
    user_nom    TEXT,
    user_initiales TEXT,
    lu_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (message_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_liaison_messages_etab_date
    ON liaison_messages (etablissement, created_at DESC);

ALTER TABLE liaison_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS liaison_messages_anon_all ON liaison_messages;
CREATE POLICY liaison_messages_anon_all ON liaison_messages
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE liaison_lectures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS liaison_lectures_anon_all ON liaison_lectures;
CREATE POLICY liaison_lectures_anon_all ON liaison_lectures
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Verification attendue : 2 lignes
-- SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'liaison%';
