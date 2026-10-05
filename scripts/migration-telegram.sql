-- ============================================================================
-- Migration : notifications Telegram pour l administrateur (05/10/2026)
--
-- telegram_config : petite table cle/valeur reservee aux edge functions.
--   - chat_id_admin   : identifiant du chat Telegram d Eric (rempli au setup)
--   - dernier_digest  : horodatage du dernier recapitulatif envoye
--
-- SECURITE : RLS active SANS policy anon. Le repo GitHub est public (la cle
-- anon y figure), donc cette table ne doit etre accessible que via le
-- service role utilise par les edge functions. C est une exception VOULUE
-- a la regle PBT "policy permissive anon sur toute nouvelle table".
-- ============================================================================

CREATE TABLE IF NOT EXISTS telegram_config (
    cle        text PRIMARY KEY,
    valeur     text,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE telegram_config ENABLE ROW LEVEL SECURITY;
-- Pas de CREATE POLICY : aucun acces anon, seul le service role passe.

-- Verification post-migration :
-- SELECT * FROM telegram_config;                       -- (via service role)
-- SELECT tablename, policyname FROM pg_policies WHERE tablename = 'telegram_config';  -- doit etre vide
