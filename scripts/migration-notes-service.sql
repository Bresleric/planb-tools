-- ============================================================================
-- Migration : module Notes de service (notes + registre des lectures signees)
-- A executer dans Supabase SQL Editor (ou via MCP) - idempotente.
-- Regle PBT : RLS + policy anon sur toute nouvelle table.
-- ============================================================================

CREATE TABLE IF NOT EXISTS notes_service (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero           TEXT,
    titre            TEXT NOT NULL,
    contenu          TEXT NOT NULL,
    etablissement    TEXT NOT NULL DEFAULT 'tous',     -- freddy | liesel | tous
    date_publication DATE NOT NULL DEFAULT CURRENT_DATE,
    date_expiration  DATE,
    actif            BOOLEAN NOT NULL DEFAULT true,
    publie_par_id    UUID,
    publie_par_nom   TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notes_service_lectures (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    note_id         UUID NOT NULL REFERENCES notes_service(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL,
    user_nom        TEXT,
    user_initiales  TEXT,
    etablissement   TEXT,
    lu_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (note_id, user_id)
);

ALTER TABLE notes_service ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notes_service_anon_all ON notes_service;
CREATE POLICY notes_service_anon_all ON notes_service
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE notes_service_lectures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notes_service_lectures_anon_all ON notes_service_lectures;
CREATE POLICY notes_service_lectures_anon_all ON notes_service_lectures
    AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Verification attendue : 2 lignes
-- SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'notes_service%';
