-- ============================================================================
-- Cahier de liaison : modification des messages publies (14/10/2026)
-- STATUT : APPLIQUEE en base via MCP le 14/10/2026. Idempotent.
-- Trace de la derniere modification (auteur ou responsable+), affichee sous
-- le message ("modifie par X"). La table garde sa policy pbt_session.
-- ============================================================================
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS modifie_le timestamptz;
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS modifie_par_nom text;
