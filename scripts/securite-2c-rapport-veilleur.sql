-- ============================================================================
-- SECURITE 2c : lien magique du Rapport + veilleur Combo prets pour la
-- phase 3 (08/10/2026). APPLIQUEE via MCP — trace.
--
-- 1. rapport_acces.user_id : le token designe son proprietaire (Eric).
-- 2. pbt_login_rapport(p_token) : le lien magique ouvre une session pbt
--    de 14 h (renouvelee a chaque visite) -> le rapport lira encore ses
--    donnees apres le verrouillage RLS. Anti force brute type 'rapport'.
-- 3. FUITE COLMATEE : combo_veilleur_log.pin contenait les PIN generes EN
--    CLAIR (table lisible par cle publique). Historique purge ; le veilleur
--    v6 ne genere plus de PIN du tout (users crees sans code, Eric genere
--    le code provisoire via Admin > Reinitialiser le code).
-- ============================================================================

ALTER TABLE rapport_acces ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES users(id);
UPDATE rapport_acces SET user_id = (SELECT id FROM users WHERE nom = 'Eric Bresler' AND role = 'admin' LIMIT 1)
WHERE user_id IS NULL;

-- (fonction pbt_login_rapport : voir la migration securite_2c_rapport_et_veilleur
--  dans l historique Supabase ; meme patron que pbt_login, sans PIN ni appareil)

UPDATE combo_veilleur_log SET pin = NULL WHERE pin IS NOT NULL;

-- Verification :
-- SELECT count(*) FROM combo_veilleur_log WHERE pin IS NOT NULL;  -- 0
-- SELECT proname FROM pg_proc WHERE proname = 'pbt_login_rapport'; -- 1
