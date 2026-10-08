-- ============================================================================
-- SECURITE Phase 3/3 : VERROUILLAGE (execution programmee 09/10/2026 02:00)
-- Ce fichier est le plan d execution de la moulinette de nuit. Chaque bloc
-- est joue separement via MCP (repli pg_cron si gel DDL), avec verification.
--
-- OBJECTIF : plus AUCUNE donnee lisible ou modifiable avec la seule cle
-- publique. Tout acces aux tables exige une session pbt valide (connexion
-- PIN, ou lien magique du rapport). Le service role (edge functions, pg_cron)
-- n est pas concerne (il contourne RLS).
--
-- RETOUR ARRIERE : bloc R en fin de fichier (reouverture en ~30 s), grace a
-- la sauvegarde prealable des policies actuelles (bloc 0).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- BLOC 0 : SAUVEGARDE des policies actuelles (rollback possible a tout moment)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pbt_private.policies_sauvegarde AS
SELECT now() AS sauvegarde_le, schemaname, tablename, policyname, permissive,
       roles::text AS roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public', 'storage');

-- ---------------------------------------------------------------------------
-- BLOC 1 : RLS actif sur TOUTES les tables public + policy unique pbt_session
--          (remplace les 125 policies permissives). Exceptions :
--          - telegram_config : reste sans policy (service role uniquement)
--          - users : lecture avec session, ecriture reservee admin (bloc 2)
-- ---------------------------------------------------------------------------
DO $$
DECLARE t record; p record;
BEGIN
  FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public'
           AND tablename NOT IN ('telegram_config')
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = t.tablename
    LOOP
      EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t.tablename);
    END LOOP;
    IF t.tablename = 'users' THEN
      EXECUTE 'CREATE POLICY pbt_session_lecture ON public.users FOR SELECT TO authenticated USING ((select public.pbt_session_ok()))';
      EXECUTE 'CREATE POLICY pbt_admin_insert ON public.users FOR INSERT TO authenticated WITH CHECK ((select public.pbt_role()) = ''admin'')';
      EXECUTE 'CREATE POLICY pbt_admin_update ON public.users FOR UPDATE TO authenticated USING ((select public.pbt_role()) = ''admin'') WITH CHECK ((select public.pbt_role()) = ''admin'')';
      EXECUTE 'CREATE POLICY pbt_admin_delete ON public.users FOR DELETE TO authenticated USING ((select public.pbt_role()) = ''admin'')';
    ELSE
      EXECUTE format('CREATE POLICY pbt_session ON public.%I FOR ALL TO authenticated USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()))', t.tablename);
    END IF;
  END LOOP;
END $$;

-- Verification : SELECT count(*) FROM pg_policies WHERE schemaname='public'
--   AND policyname NOT LIKE 'pbt%';   -- attendu : 0

-- ---------------------------------------------------------------------------
-- BLOC 2 : les fonctions pbt ne recopient plus users.code (colonne supprimee
--          au bloc 3). Seules les lignes de transition sont retirees.
-- ---------------------------------------------------------------------------
-- (CREATE OR REPLACE de pbt_changer_pin et pbt_admin_reinitialiser_pin,
--  identiques a la phase 1 SANS le bloc "TRANSITION ... users.code" --
--  voir la migration securite_3_fonctions dans l historique Supabase)

-- ---------------------------------------------------------------------------
-- BLOC 3 : fin de la colonne users.code (les PIN ne vivent plus qu en hache)
-- ---------------------------------------------------------------------------
DROP TRIGGER IF EXISTS users_sync_pin ON public.users;
ALTER TABLE public.users DROP COLUMN IF EXISTS code;   -- repli pg_cron si gel

-- ---------------------------------------------------------------------------
-- BLOC 4 : les vues respectent le RLS de leurs tables sources
-- ---------------------------------------------------------------------------
ALTER VIEW public.pointages_unifies        SET (security_invoker = true);
ALTER VIEW public.stock_par_article        SET (security_invoker = true);
ALTER VIEW public.stock_par_lot            SET (security_invoker = true);
ALTER VIEW public.v_factures_prix_articles SET (security_invoker = true);
ALTER VIEW public.v_informations_visibles  SET (security_invoker = true);
ALTER VIEW public.v_prix_ingredients_factures SET (security_invoker = true);
ALTER VIEW public.v_prix_ingredients_uv    SET (security_invoker = true);
ALTER VIEW public.v_scans_avec_signature   SET (security_invoker = true);
ALTER VIEW public.v_stock_pf_pi_par_produit SET (security_invoker = true);

-- ---------------------------------------------------------------------------
-- BLOC 5 : Storage - buckets prives + acces sur session uniquement
--          (le front du cahier de liaison utilise des URLs signees depuis v96 ;
--           le module Information est retire du portail depuis le 06/10)
-- ---------------------------------------------------------------------------
UPDATE storage.buckets SET public = false WHERE id IN ('liaison-images', 'information-images');

DO $$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname);
  END LOOP;
END $$;
CREATE POLICY pbt_storage_lecture ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('scans','liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));
CREATE POLICY pbt_storage_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('scans','liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));
CREATE POLICY pbt_storage_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));
-- (scans : suppression/modification reservees au service role, comme avant)

-- ---------------------------------------------------------------------------
-- BLOC 6 : BANC DE TEST AUTOMATIQUE (leçon du 07/10)
-- ---------------------------------------------------------------------------
-- A. SANS session (JWT anonyme simule, aucune session pbt) :
--    users, briefings, caisse_controle, ventes_journalieres, liaison_messages,
--    tasks, productions, combo_pointages -> 0 ligne lisible ; INSERT tasks
--    et liaison_messages -> refus RLS. C est le test du "monsieur du mail".
-- B. AVEC session (session pbt inseree pour Eric + JWT simule) :
--    lecture > 0 sur ~15 tables cles ; INSERT puis DELETE sur tasks et
--    liaison_messages ; vue stock_par_lot lisible ; pbt_verifier_pin repond.
-- C. API REST reelle via pg_net avec la SEULE cle anon (sans session) :
--    GET /rest/v1/users?select=nom -> [] attendu.
-- D. get_advisors (security) : plus d alerte RLS ouverte.

-- ---------------------------------------------------------------------------
-- BLOC R : RETOUR ARRIERE D URGENCE (reouverture comme avant la phase 3)
-- ---------------------------------------------------------------------------
-- DO $$
-- DECLARE t record; p record;
-- BEGIN
--   FOR t IN SELECT DISTINCT tablename FROM pbt_private.policies_sauvegarde WHERE schemaname='public'
--   LOOP
--     FOR p IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename=t.tablename LOOP
--       EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t.tablename);
--     END LOOP;
--     EXECUTE format('CREATE POLICY ouverture_urgence ON public.%I FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)', t.tablename);
--   END LOOP;
-- END $$;
-- UPDATE storage.buckets SET public = true WHERE id IN ('liaison-images','information-images');
-- + recreer les policies storage depuis pbt_private.policies_sauvegarde
-- ============================================================================
