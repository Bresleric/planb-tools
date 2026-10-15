-- ============================================================================
-- Cahier de liaison : trace de l archivage (15/10/2026)
-- Idempotent : rejouable sans risque.
-- Qui a archive un fil et quand ("Archive par X le JJ/MM" dans l onglet
-- Archives). L archivage est reserve a l admin ; la question et ses
-- reponses sont archivees ensemble. La table garde sa policy pbt_session.
-- ============================================================================
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS archive_par_id uuid;
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS archive_par_nom text;
ALTER TABLE liaison_messages ADD COLUMN IF NOT EXISTS archive_le timestamptz;
