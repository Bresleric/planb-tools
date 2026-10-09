-- ============================================================================
-- SECURITE Phase 3/3 : VERROUILLAGE COMPLET — APPLIQUEE le 09/10/2026 a 06h40
-- (collage Eric dans SQL Editor apres echec de la moulinette automatique).
-- BANC DE TEST : sans session = 0 ligne partout + ecritures refusees ;
-- avec session = lectures/ecritures OK sur toutes les tables cles ;
-- API REST avec cle anon seule = [] sur users et briefings ;
-- advisors : plus aucune alerte RLS ouverte.
--
-- La moulinette automatique de 02h00 a ete empechee par la couche d acces
-- distante (annulation systematique a 60 s de tout DDL de masse cette nuit,
-- etat verifie PROPRE : rien n a ete modifie). L editeur SQL du dashboard
-- s execute directement sur le serveur : ce script y passe en quelques
-- secondes. IDEMPOTENT : rejouable sans danger.
--
-- RETOUR ARRIERE : bloc R tout en bas (reouverture en ~30 s).
-- ============================================================================

-- ---------- BLOC 0 : sauvegarde des policies (deja faite a 02h00, idempotent)
CREATE TABLE IF NOT EXISTS pbt_private.policies_sauvegarde AS
SELECT now() AS sauvegarde_le, schemaname, tablename, policyname, permissive,
       roles::text AS roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public', 'storage');

-- ---------- BLOC 1 : policy unique pbt_session sur toutes les tables public
DO $do1$
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
END $do1$;

-- ---------- BLOC 2 : fonctions sans recopie users.code (colonne supprimee bloc 3)
CREATE OR REPLACE FUNCTION public.pbt_changer_pin(p_ancien text, p_nouveau text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_uid uuid := public.pbt_user_id();
    v_ip  text := pbt_private.ip_client();
BEGIN
    IF v_uid IS NULL THEN RAISE EXCEPTION 'session requise'; END IF;
    IF pbt_private.trop_de_tentatives('changer_pin', v_ip) THEN
        RAISE EXCEPTION 'Trop de tentatives - reessaie dans 15 minutes';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pbt_private.user_pins
                   WHERE user_id = v_uid AND pin_hash = pbt_private.hash_pin(p_ancien)) THEN
        PERFORM pbt_private.log_tentative('changer_pin', false, v_uid);
        RAISE EXCEPTION 'Ancien code incorrect';
    END IF;
    IF NOT pbt_private.pin_valide(p_nouveau) THEN
        PERFORM pbt_private.log_tentative('changer_pin', false, v_uid);
        RAISE EXCEPTION 'Code refuse - choisis 6 chiffres non triviaux';
    END IF;
    BEGIN
        UPDATE pbt_private.user_pins
           SET pin_hash = pbt_private.hash_pin(p_nouveau), doit_changer = false, modifie_le = now()
         WHERE user_id = v_uid;
    EXCEPTION WHEN unique_violation THEN
        PERFORM pbt_private.log_tentative('changer_pin', false, v_uid);
        RAISE EXCEPTION 'Code refuse';
    END;
    PERFORM pbt_private.log_tentative('changer_pin', true, v_uid);
    RETURN jsonb_build_object('ok', true);
END $$;

CREATE OR REPLACE FUNCTION public.pbt_admin_reinitialiser_pin(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_pin text;
    i int := 0;
BEGIN
    IF public.pbt_role() IS DISTINCT FROM 'admin' THEN RAISE EXCEPTION 'reserve a l administrateur'; END IF;
    LOOP
        i := i + 1;
        v_pin := lpad(floor(random() * 1000000)::int::text, 6, '0');
        CONTINUE WHEN NOT pbt_private.pin_valide(v_pin);
        BEGIN
            INSERT INTO pbt_private.user_pins (user_id, pin_hash, doit_changer, modifie_le)
            VALUES (p_user_id, pbt_private.hash_pin(v_pin), true, now())
            ON CONFLICT (user_id) DO UPDATE
                SET pin_hash = EXCLUDED.pin_hash, doit_changer = true, modifie_le = now();
            EXIT;
        EXCEPTION WHEN unique_violation THEN
            IF i > 20 THEN RAISE EXCEPTION 'generation impossible - reessayer'; END IF;
        END;
    END LOOP;
    RETURN jsonb_build_object('pin_provisoire', v_pin);
END $$;

-- ---------- BLOC 3 : fin des codes en clair
DROP TRIGGER IF EXISTS users_sync_pin ON public.users;
ALTER TABLE public.users DROP COLUMN IF EXISTS code;

-- ---------- BLOC 4 : les vues respectent le RLS des tables sources
ALTER VIEW public.pointages_unifies           SET (security_invoker = true);
ALTER VIEW public.stock_par_article           SET (security_invoker = true);
ALTER VIEW public.stock_par_lot               SET (security_invoker = true);
ALTER VIEW public.v_factures_prix_articles    SET (security_invoker = true);
ALTER VIEW public.v_informations_visibles     SET (security_invoker = true);
ALTER VIEW public.v_prix_ingredients_factures SET (security_invoker = true);
ALTER VIEW public.v_prix_ingredients_uv       SET (security_invoker = true);
ALTER VIEW public.v_scans_avec_signature      SET (security_invoker = true);
ALTER VIEW public.v_stock_pf_pi_par_produit   SET (security_invoker = true);

-- ---------- BLOC 5 : Storage prive, acces sur session
UPDATE storage.buckets SET public = false WHERE id IN ('liaison-images', 'information-images');

DO $do5$
DECLARE p record;
BEGIN
  FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects'
  LOOP
    EXECUTE format('DROP POLICY %I ON storage.objects', p.policyname);
  END LOOP;
END $do5$;
CREATE POLICY pbt_storage_lecture ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id IN ('scans','liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));
CREATE POLICY pbt_storage_insert ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id IN ('scans','liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));
CREATE POLICY pbt_storage_delete ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id IN ('liaison-images','information-images','information-attachments')
         AND (select public.pbt_session_ok()));

-- ---------- VERIFICATION FINALE (doit afficher 0 / 0 / 0 / 2)
SELECT
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'public' AND policyname NOT LIKE 'pbt%')  AS policies_non_pbt,
  (SELECT count(*) FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'code') AS colonne_code,
  (SELECT count(*) FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname NOT LIKE 'pbt%') AS storage_non_pbt,
  (SELECT count(*) FROM storage.buckets WHERE id IN ('liaison-images','information-images') AND NOT public) AS buckets_prives;

-- ============================================================================
-- BLOC R : RETOUR ARRIERE D URGENCE (decommenter puis Run)
-- ============================================================================
-- DO $$
-- DECLARE t record; p record;
-- BEGIN
--   FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename <> 'telegram_config'
--   LOOP
--     FOR p IN SELECT policyname FROM pg_policies WHERE schemaname = 'public' AND tablename = t.tablename LOOP
--       EXECUTE format('DROP POLICY %I ON public.%I', p.policyname, t.tablename);
--     END LOOP;
--     EXECUTE format('CREATE POLICY ouverture_urgence ON public.%I FOR ALL TO anon, authenticated USING (true) WITH CHECK (true)', t.tablename);
--   END LOOP;
-- END $$;
-- UPDATE storage.buckets SET public = true WHERE id IN ('liaison-images','information-images');
-- CREATE POLICY urgence_storage ON storage.objects FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
-- ============================================================================
