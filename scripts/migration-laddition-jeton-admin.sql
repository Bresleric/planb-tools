-- ============================================================================
-- Migration : jeton L Addition renouvele depuis le module Admin (26/11/2026)
-- Idempotent : rejouable sans risque. Pas de nouvelle table.
--
-- Contexte : le refreshToken L Addition vit 18 a 19 jours, sans prolongation.
-- Jusqu ici il fallait le coller dans le SQL Editor. Desormais :
--   1. pbt_private.config.laddition_jeton_colle_le : date du dernier jeton colle
--   2. pbt_admin_laddition_jeton(p_jeton) : enregistre un nouveau jeton
--      (administrateur PBT seulement, ne renvoie jamais la valeur)
--   3. pbt_admin_laddition_etat() : date du jeton, age, expiration estimee,
--      derniere synchro (administrateur seulement, jamais le jeton)
--   4. Cron quotidien laddition-jeton-rappel -> telegram-notif (rappel Telegram
--      a partir du 15e jour, un message par jour maximum)
--
-- Verification en fin de fichier.
-- ============================================================================

-- 1. Date du dernier jeton colle (initialisee au 24/11/2026, dernier collage)
INSERT INTO pbt_private.config (cle, valeur)
VALUES ('laddition_jeton_colle_le', '2026-11-24T12:00:00+01:00')
ON CONFLICT (cle) DO NOTHING;

-- 2. Enregistrement d un nouveau jeton par un administrateur -----------------
CREATE OR REPLACE FUNCTION public.pbt_admin_laddition_jeton(p_jeton text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_jeton text := regexp_replace(coalesce(p_jeton, ''), '\s', '', 'g');
    v_now   timestamptz := now();
BEGIN
    IF public.pbt_role() IS DISTINCT FROM 'admin' THEN
        RAISE EXCEPTION 'reserve a l administrateur';
    END IF;
    -- Un refreshToken L Addition est une longue chaine opaque ; on refuse
    -- l evidence (vide, trop court, guillemets ou "refreshToken=" copies avec)
    v_jeton := regexp_replace(v_jeton, '^refreshToken=', '');
    v_jeton := trim(both '"''' from v_jeton);
    IF length(v_jeton) < 20 THEN
        RAISE EXCEPTION 'jeton trop court : copier la VALEUR du cookie refreshToken';
    END IF;

    INSERT INTO pbt_private.config (cle, valeur) VALUES ('laddition_refresh_token', v_jeton)
    ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
    INSERT INTO pbt_private.config (cle, valeur) VALUES ('laddition_access_token', '')
    ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
    INSERT INTO pbt_private.config (cle, valeur) VALUES ('laddition_jeton_colle_le', v_now::text)
    ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;
    -- Le rappel quotidien repart de zero pour ce nouveau jeton
    INSERT INTO pbt_private.config (cle, valeur) VALUES ('laddition_rappel_jeton_le', '')
    ON CONFLICT (cle) DO UPDATE SET valeur = EXCLUDED.valeur;

    RETURN jsonb_build_object('ok', true, 'colle_le', v_now);
END $function$;

REVOKE ALL ON FUNCTION public.pbt_admin_laddition_jeton(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pbt_admin_laddition_jeton(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.pbt_admin_laddition_jeton(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_admin_laddition_jeton(text) TO service_role;

-- 3. Etat du jeton pour la case Admin (jamais la valeur du jeton) -----------
CREATE OR REPLACE FUNCTION public.pbt_admin_laddition_etat()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
    v_colle   timestamptz;
    v_present boolean;
    v_live    jsonb;
BEGIN
    IF public.pbt_role() IS DISTINCT FROM 'admin' THEN
        RAISE EXCEPTION 'reserve a l administrateur';
    END IF;
    SELECT nullif(valeur, '')::timestamptz INTO v_colle FROM pbt_private.config WHERE cle = 'laddition_jeton_colle_le';
    SELECT coalesce(valeur, '') <> '' INTO v_present FROM pbt_private.config WHERE cle = 'laddition_refresh_token';
    SELECT jsonb_agg(jsonb_build_object(
        'etablissement', l.etablissement, 'date_service', l.date_service, 'ca', l.ca,
        'couverts', l.couverts, 'synchro_le', l.synchro_le, 'erreur', l.erreur, 'erreur_le', l.erreur_le
    ) ORDER BY l.etablissement) INTO v_live FROM public.laddition_live l;

    RETURN jsonb_build_object(
        'jeton_present', coalesce(v_present, false),
        'colle_le', v_colle,
        'age_jours', CASE WHEN v_colle IS NULL THEN NULL ELSE floor(extract(epoch FROM (now() - v_colle)) / 86400)::int END,
        'expire_vers', CASE WHEN v_colle IS NULL THEN NULL ELSE (v_colle + interval '18 days') END,
        'live', coalesce(v_live, '[]'::jsonb)
    );
END $function$;

REVOKE ALL ON FUNCTION public.pbt_admin_laddition_etat() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pbt_admin_laddition_etat() FROM anon;
GRANT EXECUTE ON FUNCTION public.pbt_admin_laddition_etat() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_admin_laddition_etat() TO service_role;

-- 4. Rappel Telegram quotidien : 8h UTC = 9h Paris en hiver, 10h en ete ------
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'laddition-jeton-rappel') THEN
    PERFORM cron.unschedule('laddition-jeton-rappel');
  END IF;
END $$;

SELECT cron.schedule('laddition-jeton-rappel', '0 8 * * *', $cron$
  SELECT net.http_post(
    url := 'https://dzrherfavgiuygnimtux.supabase.co/functions/v1/telegram-notif',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR6cmhlcmZhdmdpdXlnbmltdHV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1MDQ2MzYsImV4cCI6MjA5MDA4MDYzNn0.4LVwGERblZ0R5EP9EEql639TAojQEEyj2dV9K3sMxMQ"}'::jsonb,
    body := '{"action":"jeton_laddition"}'::jsonb,
    timeout_milliseconds := 30000
  );
$cron$);

-- Verification ---------------------------------------------------------------
SELECT p.proname, r.grantee, r.privilege_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
LEFT JOIN information_schema.routine_privileges r ON r.routine_name = p.proname AND r.specific_schema = 'public'
WHERE n.nspname = 'public' AND p.proname IN ('pbt_admin_laddition_jeton', 'pbt_admin_laddition_etat')
ORDER BY 1, 2;
SELECT jobname, schedule FROM cron.job WHERE jobname = 'laddition-jeton-rappel';
SELECT cle, CASE WHEN cle LIKE '%_le' THEN valeur ELSE '(masque)' END AS valeur
FROM pbt_private.config WHERE cle LIKE 'laddition%' ORDER BY cle;
