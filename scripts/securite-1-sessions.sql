-- ============================================================================
-- SECURITE Phase 1/3 : fondations des sessions securisees (07/10/2026)
-- Idempotent. NE TOUCHE A AUCUNE POLICY EXISTANTE : l appli actuelle
-- continue de fonctionner a l identique pendant cette phase.
--
-- Prerequis MANUEL (dashboard Supabase) : Authentication > Sign In / Up >
-- activer "Allow anonymous sign-ins" (necessaire pour signInAnonymously).
--
-- Architecture : le front ouvre une connexion Supabase ANONYME (auth.uid()),
-- puis pbt_login(PIN) cree une session PBT liee a cet auth.uid(). Les PIN
-- sont stockes HACHES (HMAC-SHA256 + pepper) dans un schema prive
-- inaccessible aux cles publiques. users.code reste en place (et synchronise
-- dans les deux sens) jusqu a la phase 3 pour ne rien casser.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- ----------------------------------------------------------------------------
-- 1. Schema prive : invisible pour anon / authenticated / public
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS pbt_private;
REVOKE ALL ON SCHEMA pbt_private FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA pbt_private REVOKE ALL ON TABLES FROM PUBLIC, anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA pbt_private REVOKE ALL ON FUNCTIONS FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS pbt_private.config (
    cle    text PRIMARY KEY,
    valeur text NOT NULL
);
-- Pepper aleatoire genere UNE fois, jamais expose
INSERT INTO pbt_private.config (cle, valeur)
SELECT 'pepper', encode(extensions.gen_random_bytes(32), 'hex')
WHERE NOT EXISTS (SELECT 1 FROM pbt_private.config WHERE cle = 'pepper');

CREATE TABLE IF NOT EXISTS pbt_private.user_pins (
    user_id      uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    pin_hash     text UNIQUE NOT NULL,
    doit_changer boolean NOT NULL DEFAULT true,
    modifie_le   timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS pbt_private.sessions (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_uid       uuid NOT NULL,
    user_id        uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    device_id      uuid,
    impersonne_par uuid REFERENCES public.users(id),
    cree_le        timestamptz NOT NULL DEFAULT now(),
    expire_le      timestamptz NOT NULL,
    revoque_le     timestamptz
);
CREATE INDEX IF NOT EXISTS sessions_auth_actives_idx
    ON pbt_private.sessions (auth_uid, cree_le DESC) WHERE revoque_le IS NULL;

CREATE TABLE IF NOT EXISTS pbt_private.tentatives (
    id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    quand   timestamptz NOT NULL DEFAULT now(),
    ip      text,
    type    text NOT NULL,
    succes  boolean NOT NULL,
    user_id uuid
);
CREATE INDEX IF NOT EXISTS tentatives_fenetre_idx ON pbt_private.tentatives (type, quand DESC);

-- ----------------------------------------------------------------------------
-- 2. Helpers prives
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pbt_private.hash_pin(p_pin text)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT encode(extensions.hmac(
        convert_to(p_pin, 'utf8'),
        convert_to((SELECT valeur FROM pbt_private.config WHERE cle = 'pepper'), 'utf8'),
        'sha256'), 'hex');
$$;

CREATE OR REPLACE FUNCTION pbt_private.ip_client()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT coalesce(
        nullif(current_setting('request.headers', true)::jsonb ->> 'cf-connecting-ip', ''),
        nullif(split_part(current_setting('request.headers', true)::jsonb ->> 'x-forwarded-for', ',', 1), ''),
        'inconnue');
$$;

-- Anti brute-force : vrai si la fenetre de 15 min depasse 5 echecs pour cette
-- IP ou 40 echecs toutes IP confondues (pour ce type de tentative)
CREATE OR REPLACE FUNCTION pbt_private.trop_de_tentatives(p_type text, p_ip text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT (SELECT count(*) FROM pbt_private.tentatives
            WHERE type = p_type AND succes = false AND ip = p_ip
              AND quand > now() - interval '15 minutes') >= 5
        OR (SELECT count(*) FROM pbt_private.tentatives
            WHERE type = p_type AND succes = false
              AND quand > now() - interval '15 minutes') >= 40;
$$;

CREATE OR REPLACE FUNCTION pbt_private.log_tentative(p_type text, p_succes boolean, p_user uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    INSERT INTO pbt_private.tentatives (ip, type, succes, user_id)
    VALUES (pbt_private.ip_client(), p_type, p_succes, p_user);
$$;

-- Validation d un nouveau PIN : 6 chiffres, ni trivial ni sequence
CREATE OR REPLACE FUNCTION pbt_private.pin_valide(p_pin text)
RETURNS boolean LANGUAGE sql IMMUTABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT p_pin ~ '^[0-9]{6}$'
       AND p_pin NOT IN ('000000','111111','222222','333333','444444','555555',
                         '666666','777777','888888','999999','123456','654321',
                         '012345','543210','123123','112233')
       AND p_pin !~ '^(\d)\1{5}$';
$$;

-- ----------------------------------------------------------------------------
-- 3. Reprise des codes existants + synchro TEMPORAIRE users.code -> user_pins
--    (retiree en phase 3 avec la colonne users.code)
-- ----------------------------------------------------------------------------
INSERT INTO pbt_private.user_pins (user_id, pin_hash, doit_changer)
SELECT u.id, pbt_private.hash_pin(u.code), true
FROM public.users u
WHERE u.code IS NOT NULL AND length(u.code) BETWEEN 4 AND 6
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION pbt_private.sync_pin_from_users()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    -- Garde : quand une fonction pbt_* ecrit elle-meme users.code, elle pose
    -- ce drapeau pour eviter que le trigger n ecrase doit_changer
    IF current_setting('pbt.skip_sync', true) = '1' THEN RETURN NEW; END IF;
    IF NEW.code IS NOT NULL AND length(NEW.code) BETWEEN 4 AND 6 THEN
        BEGIN
            INSERT INTO pbt_private.user_pins (user_id, pin_hash, doit_changer, modifie_le)
            VALUES (NEW.id, pbt_private.hash_pin(NEW.code), true, now())
            ON CONFLICT (user_id) DO UPDATE
                SET pin_hash = EXCLUDED.pin_hash, doit_changer = true, modifie_le = now();
        EXCEPTION WHEN unique_violation THEN
            -- PIN deja pris par un autre utilisateur : on ne synchronise pas
            NULL;
        END;
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS users_sync_pin ON public.users;
CREATE TRIGGER users_sync_pin
    AFTER INSERT OR UPDATE OF code ON public.users
    FOR EACH ROW EXECUTE FUNCTION pbt_private.sync_pin_from_users();

-- ----------------------------------------------------------------------------
-- 4. Fonctions publiques (RPC du front) - SECURITY DEFINER, search_path vide
-- ----------------------------------------------------------------------------

-- Identite de la session courante (NULL si aucune session valide)
CREATE OR REPLACE FUNCTION public.pbt_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT s.user_id FROM pbt_private.sessions s
    WHERE s.auth_uid = auth.uid()
      AND s.revoque_le IS NULL AND s.expire_le > now()
    ORDER BY s.cree_le DESC LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.pbt_session_ok()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT public.pbt_user_id() IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.pbt_role()
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT u.role FROM public.users u WHERE u.id = public.pbt_user_id();
$$;

-- Connexion par PIN. Exige une connexion Supabase anonyme prealable.
CREATE OR REPLACE FUNCTION public.pbt_login(p_pin text, p_device_token text DEFAULT NULL, p_memoriser boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_auth uuid := auth.uid();
    v_ip   text := pbt_private.ip_client();
    v_user public.users%ROWTYPE;
    v_pin  pbt_private.user_pins%ROWTYPE;
    v_dev  public.devices%ROWTYPE;
    v_exp  timestamptz;
    v_etabs text[];
BEGIN
    IF v_auth IS NULL THEN RAISE EXCEPTION 'connexion anonyme requise'; END IF;
    IF pbt_private.trop_de_tentatives('login', v_ip) THEN
        PERFORM pbt_private.log_tentative('login', false, NULL);
        RAISE EXCEPTION 'Trop de tentatives - reessaie dans 15 minutes';
    END IF;

    SELECT * INTO v_pin FROM pbt_private.user_pins WHERE pin_hash = pbt_private.hash_pin(p_pin);
    IF FOUND THEN
        SELECT * INTO v_user FROM public.users WHERE id = v_pin.user_id AND actif = true;
    END IF;
    IF v_user.id IS NULL THEN
        PERFORM pbt_private.log_tentative('login', false, NULL);
        RAISE EXCEPTION 'Code incorrect';
    END IF;

    IF p_device_token IS NOT NULL THEN
        SELECT * INTO v_dev FROM public.devices WHERE device_token = p_device_token AND actif = true;
    END IF;
    -- Exigence serveur (jusque-la seulement cote navigateur) :
    -- un collaborateur ne se connecte que depuis un appareil active
    IF v_user.role = 'collaborateur' AND v_dev.id IS NULL THEN
        PERFORM pbt_private.log_tentative('login', false, v_user.id);
        RAISE EXCEPTION 'Appareil non autorise - active cet appareil d abord';
    END IF;

    UPDATE pbt_private.sessions SET revoque_le = now()
    WHERE auth_uid = v_auth AND revoque_le IS NULL;

    v_exp := now() + CASE WHEN v_user.role = 'admin' AND p_memoriser
                          THEN interval '30 days' ELSE interval '14 hours' END;
    INSERT INTO pbt_private.sessions (auth_uid, user_id, device_id, expire_le)
    VALUES (v_auth, v_user.id, v_dev.id, v_exp);

    PERFORM pbt_private.log_tentative('login', true, v_user.id);
    SELECT array_agg(DISTINCT e) INTO v_etabs FROM unnest(
        ARRAY[v_user.etablissement] || coalesce(v_user.acces_etablissements, '{}')) AS e WHERE e IS NOT NULL;

    RETURN jsonb_build_object(
        'user', jsonb_build_object(
            'id', v_user.id, 'nom', v_user.nom, 'initiales', v_user.initiales,
            'role', v_user.role, 'equipe', v_user.equipe,
            'acces_modules', v_user.acces_modules, 'etablissements', v_etabs),
        'doit_changer_code', v_pin.doit_changer,
        'device', CASE WHEN v_dev.id IS NULL THEN NULL
                       ELSE jsonb_build_object('id', v_dev.id, 'nom', v_dev.nom) END,
        'expire_le', v_exp);
END $$;

-- Activation d un iPad par code a 6 chiffres (reprend activateDevice du front)
CREATE OR REPLACE FUNCTION public.pbt_activer_appareil(p_code text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_ip  text := pbt_private.ip_client();
    v_dev public.devices%ROWTYPE;
BEGIN
    IF auth.uid() IS NULL THEN RAISE EXCEPTION 'connexion anonyme requise'; END IF;
    IF pbt_private.trop_de_tentatives('activation', v_ip) THEN
        PERFORM pbt_private.log_tentative('activation', false, NULL);
        RAISE EXCEPTION 'Trop de tentatives - reessaie dans 15 minutes';
    END IF;
    SELECT * INTO v_dev FROM public.devices WHERE code_activation = p_code;
    IF v_dev.id IS NULL THEN
        PERFORM pbt_private.log_tentative('activation', false, NULL);
        RAISE EXCEPTION 'Code d activation invalide';
    END IF;
    IF v_dev.date_enregistrement IS NOT NULL THEN
        PERFORM pbt_private.log_tentative('activation', false, NULL);
        RETURN jsonb_build_object('error', 'already_activated');
    END IF;
    UPDATE public.devices
       SET date_enregistrement = now(), derniere_connexion = now()
     WHERE id = v_dev.id
    RETURNING * INTO v_dev;
    PERFORM pbt_private.log_tentative('activation', true, NULL);
    RETURN jsonb_build_object('id', v_dev.id, 'nom', v_dev.nom,
                              'device_token', v_dev.device_token, 'actif', v_dev.actif);
END $$;

CREATE OR REPLACE FUNCTION public.pbt_logout()
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
    UPDATE pbt_private.sessions SET revoque_le = now()
    WHERE auth_uid = auth.uid() AND revoque_le IS NULL;
$$;

-- Changement de PIN (6 chiffres, pas de code trivial, unicite silencieuse)
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
        RAISE EXCEPTION 'Code refuse';   -- ne jamais reveler qu il est pris
    END;
    -- TRANSITION (retire en phase 3) : recopie dans users.code pour que les
    -- ecrans non encore redeployes continuent de fonctionner
    PERFORM set_config('pbt.skip_sync', '1', true);
    UPDATE public.users SET code = p_nouveau WHERE id = v_uid;
    PERFORM set_config('pbt.skip_sync', '0', true);
    PERFORM pbt_private.log_tentative('changer_pin', true, v_uid);
    RETURN jsonb_build_object('ok', true);
END $$;

-- Verification PIN (ecrans de verrouillage / signatures des modules)
CREATE OR REPLACE FUNCTION public.pbt_verifier_pin(p_pin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_ip   text := pbt_private.ip_client();
    v_user public.users%ROWTYPE;
BEGIN
    IF public.pbt_user_id() IS NULL THEN RAISE EXCEPTION 'session requise'; END IF;
    IF pbt_private.trop_de_tentatives('verif', v_ip) THEN
        PERFORM pbt_private.log_tentative('verif', false, NULL);
        RAISE EXCEPTION 'Trop de tentatives - reessaie dans 15 minutes';
    END IF;
    SELECT u.* INTO v_user
    FROM pbt_private.user_pins up JOIN public.users u ON u.id = up.user_id
    WHERE up.pin_hash = pbt_private.hash_pin(p_pin) AND u.actif = true;
    IF v_user.id IS NULL THEN
        PERFORM pbt_private.log_tentative('verif', false, NULL);
        RETURN NULL;
    END IF;
    PERFORM pbt_private.log_tentative('verif', true, v_user.id);
    RETURN jsonb_build_object('id', v_user.id, 'nom', v_user.nom,
        'initiales', v_user.initiales, 'role', v_user.role, 'equipe', v_user.equipe,
        'etablissement', v_user.etablissement,
        'acces_etablissements', v_user.acces_etablissements);
END $$;

-- Reinitialisation par l admin : PIN provisoire affiche UNE seule fois
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
    -- TRANSITION (retire en phase 3) : recopie en clair pour les ecrans non redeployes
    PERFORM set_config('pbt.skip_sync', '1', true);
    UPDATE public.users SET code = v_pin WHERE id = p_user_id;
    PERFORM set_config('pbt.skip_sync', '0', true);
    RETURN jsonb_build_object('pin_provisoire', v_pin);
END $$;

-- Voir l appli comme un autre utilisateur (admin, journalise)
CREATE OR REPLACE FUNCTION public.pbt_admin_voir_comme(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_admin uuid := public.pbt_user_id();
    v_user  public.users%ROWTYPE;
BEGIN
    IF public.pbt_role() IS DISTINCT FROM 'admin' THEN RAISE EXCEPTION 'reserve a l administrateur'; END IF;
    SELECT * INTO v_user FROM public.users WHERE id = p_user_id AND actif = true;
    IF v_user.id IS NULL THEN RAISE EXCEPTION 'utilisateur introuvable'; END IF;
    UPDATE pbt_private.sessions SET revoque_le = now()
    WHERE auth_uid = auth.uid() AND revoque_le IS NULL;
    INSERT INTO pbt_private.sessions (auth_uid, user_id, impersonne_par, expire_le)
    VALUES (auth.uid(), p_user_id, v_admin, now() + interval '2 hours');
    RETURN jsonb_build_object('id', v_user.id, 'nom', v_user.nom,
        'initiales', v_user.initiales, 'role', v_user.role, 'equipe', v_user.equipe);
END $$;

CREATE OR REPLACE FUNCTION public.pbt_admin_revenir()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    v_admin uuid;
BEGIN
    SELECT s.impersonne_par INTO v_admin FROM pbt_private.sessions s
    WHERE s.auth_uid = auth.uid() AND s.revoque_le IS NULL AND s.impersonne_par IS NOT NULL
    ORDER BY s.cree_le DESC LIMIT 1;
    IF v_admin IS NULL THEN RAISE EXCEPTION 'aucune session - voir comme - active'; END IF;
    UPDATE pbt_private.sessions SET revoque_le = now()
    WHERE auth_uid = auth.uid() AND revoque_le IS NULL;
    INSERT INTO pbt_private.sessions (auth_uid, user_id, expire_le)
    VALUES (auth.uid(), v_admin, now() + interval '14 hours');
    RETURN jsonb_build_object('ok', true);
END $$;

-- Etat de la session courante (restauration au chargement d un module)
CREATE OR REPLACE FUNCTION public.pbt_ma_session()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT CASE WHEN s.id IS NULL THEN NULL ELSE jsonb_build_object(
        'user', jsonb_build_object('id', u.id, 'nom', u.nom, 'initiales', u.initiales,
            'role', u.role, 'equipe', u.equipe, 'acces_modules', u.acces_modules),
        'impersonne', s.impersonne_par IS NOT NULL,
        'expire_le', s.expire_le) END
    FROM (SELECT * FROM pbt_private.sessions
          WHERE auth_uid = auth.uid() AND revoque_le IS NULL AND expire_le > now()
          ORDER BY cree_le DESC LIMIT 1) s
    LEFT JOIN public.users u ON u.id = s.user_id;
$$;

-- ----------------------------------------------------------------------------
-- 5. Droits : RPC reservees au role authenticated (= connexion anonyme Supabase)
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.pbt_user_id(), public.pbt_session_ok(), public.pbt_role(),
    public.pbt_login(text, text, boolean), public.pbt_activer_appareil(text),
    public.pbt_logout(), public.pbt_changer_pin(text, text), public.pbt_verifier_pin(text),
    public.pbt_admin_reinitialiser_pin(uuid), public.pbt_admin_voir_comme(uuid),
    public.pbt_admin_revenir(), public.pbt_ma_session()
    FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pbt_user_id(), public.pbt_session_ok(), public.pbt_role(),
    public.pbt_login(text, text, boolean), public.pbt_activer_appareil(text),
    public.pbt_logout(), public.pbt_changer_pin(text, text), public.pbt_verifier_pin(text),
    public.pbt_admin_reinitialiser_pin(uuid), public.pbt_admin_voir_comme(uuid),
    public.pbt_admin_revenir(), public.pbt_ma_session()
    TO authenticated;

-- Verification post-migration (sans afficher de PIN) :
-- SELECT count(*) FROM pbt_private.user_pins;                       -- = nb users avec code
-- SELECT proname FROM pg_proc WHERE proname LIKE 'pbt_%';           -- 12 fonctions publiques + privees
-- SELECT cle FROM pbt_private.config;                               -- pepper present
