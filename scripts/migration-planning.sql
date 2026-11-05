-- =============================================================================
-- Module Planning (remplacement du planning Combo au 01/01/2027) - 05/11/2026
-- A coller dans Supabase -> SQL Editor. Script idempotent : relancable sans risque.
--
-- Principe :
--   planning_shifts   = brouillon de travail, visible des gestionnaires seulement
--   planning_publies  = copie publiee, la seule que voient les salaries
--   Publier remplace la copie publiee de la semaine et incremente sa version.
--   Une signature porte sur une empreinte : si les horaires du salarie changent
--   apres signature, la signature ne vaut plus et il doit signer a nouveau.
--   A partir du 01/01/2027 seulement, publier alimente aussi planning_equipes
--   (Briefing, TAF, Rapport). Avant, cette table reste alimentee par Combo.
-- =============================================================================

-- ---------- Droit de gestion ----------
CREATE OR REPLACE FUNCTION public.pbt_planning_gestion()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = public.pbt_user_id() AND u.actif = true
          AND (u.role IN ('admin', 'manager')
               OR 'planning_gestion' = ANY (coalesce(u.acces_modules, '{}'::text[])))
    );
$$;

-- ---------- Tables ----------
CREATE TABLE IF NOT EXISTS public.planning_shifts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    date_service date NOT NULL,
    etablissement text NOT NULL REFERENCES public.etablissements(id),
    nature text NOT NULL DEFAULT 'travail'
        CHECK (nature IN ('travail', 'cp', 'maladie', 'formation', 'absence', 'ferie')),
    equipe text NOT NULL DEFAULT 'autre',
    heure_debut time,
    heure_fin time,
    pause_minutes integer NOT NULL DEFAULT 0 CHECK (pause_minutes >= 0),
    poste text,
    saisi_par_id uuid,
    saisi_par_nom text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    CHECK (nature <> 'travail' OR (heure_debut IS NOT NULL AND heure_fin IS NOT NULL AND heure_debut <> heure_fin))
);
CREATE INDEX IF NOT EXISTS planning_shifts_etab_date ON public.planning_shifts (etablissement, date_service);
CREATE INDEX IF NOT EXISTS planning_shifts_user_date ON public.planning_shifts (user_id, date_service);

CREATE TABLE IF NOT EXISTS public.planning_publies (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    date_service date NOT NULL,
    etablissement text NOT NULL REFERENCES public.etablissements(id),
    nature text NOT NULL,
    equipe text NOT NULL,
    heure_debut time,
    heure_fin time,
    pause_minutes integer NOT NULL DEFAULT 0,
    poste text
);
CREATE INDEX IF NOT EXISTS planning_publies_etab_date ON public.planning_publies (etablissement, date_service);
CREATE INDEX IF NOT EXISTS planning_publies_user_date ON public.planning_publies (user_id, date_service);

CREATE TABLE IF NOT EXISTS public.planning_publications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    etablissement text NOT NULL REFERENCES public.etablissements(id),
    semaine date NOT NULL,
    version integer NOT NULL,
    nb_lignes integer NOT NULL DEFAULT 0,
    publie_le timestamptz NOT NULL DEFAULT now(),
    publie_par_id uuid,
    publie_par_nom text,
    UNIQUE (etablissement, semaine, version)
);

CREATE TABLE IF NOT EXISTS public.planning_signatures (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.users(id),
    semaine date NOT NULL,
    empreinte text NOT NULL,
    contenu jsonb NOT NULL,
    signe_le timestamptz NOT NULL DEFAULT now(),
    UNIQUE (user_id, semaine, empreinte)
);

CREATE TABLE IF NOT EXISTS public.planning_modeles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    etablissement text NOT NULL REFERENCES public.etablissements(id),
    equipe text NOT NULL,
    libelle text NOT NULL,
    heure_debut time NOT NULL,
    heure_fin time NOT NULL,
    pause_minutes integer NOT NULL DEFAULT 0 CHECK (pause_minutes >= 0),
    actif boolean NOT NULL DEFAULT true,
    created_at timestamptz DEFAULT now(),
    UNIQUE (etablissement, equipe, heure_debut, heure_fin, pause_minutes)
);

-- ---------- RLS : aucune policy pour anon ----------
ALTER TABLE public.planning_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planning_publies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planning_publications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planning_signatures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.planning_modeles ENABLE ROW LEVEL SECURITY;

-- Brouillon : gestionnaires seulement
DROP POLICY IF EXISTS pbt_planning_gestion ON public.planning_shifts;
CREATE POLICY pbt_planning_gestion ON public.planning_shifts FOR ALL TO authenticated
    USING ((select public.pbt_planning_gestion())) WITH CHECK ((select public.pbt_planning_gestion()));

-- Publie : lecture par toute session, ecriture uniquement par pbt_planning_publier
DROP POLICY IF EXISTS pbt_session_lecture ON public.planning_publies;
CREATE POLICY pbt_session_lecture ON public.planning_publies FOR SELECT TO authenticated
    USING ((select public.pbt_session_ok()));
DROP POLICY IF EXISTS pbt_session_lecture ON public.planning_publications;
CREATE POLICY pbt_session_lecture ON public.planning_publications FOR SELECT TO authenticated
    USING ((select public.pbt_session_ok()));

-- Signatures : chacun voit les siennes, les gestionnaires voient tout, ecriture par RPC
DROP POLICY IF EXISTS pbt_signature_lecture ON public.planning_signatures;
CREATE POLICY pbt_signature_lecture ON public.planning_signatures FOR SELECT TO authenticated
    USING (user_id = (select public.pbt_user_id()) OR (select public.pbt_planning_gestion()));

-- Modeles d horaires
DROP POLICY IF EXISTS pbt_session_lecture ON public.planning_modeles;
CREATE POLICY pbt_session_lecture ON public.planning_modeles FOR SELECT TO authenticated
    USING ((select public.pbt_session_ok()));
DROP POLICY IF EXISTS pbt_planning_gestion ON public.planning_modeles;
CREATE POLICY pbt_planning_gestion ON public.planning_modeles FOR ALL TO authenticated
    USING ((select public.pbt_planning_gestion())) WITH CHECK ((select public.pbt_planning_gestion()));

-- ---------- Publication d une semaine ----------
CREATE OR REPLACE FUNCTION public.pbt_planning_publier(p_etab text, p_lundi date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
    v_fin date := p_lundi + 6;
    v_bascule date := DATE '2027-01-01';
    v_user public.users%ROWTYPE;
    v_version integer;
    v_nb integer;
    v_miroir integer := 0;
BEGIN
    IF NOT public.pbt_planning_gestion() THEN RAISE EXCEPTION 'droit de gestion du planning requis'; END IF;
    IF extract(isodow FROM p_lundi) <> 1 THEN RAISE EXCEPTION 'la semaine doit commencer un lundi'; END IF;
    SELECT * INTO v_user FROM public.users WHERE id = public.pbt_user_id();
    PERFORM pg_advisory_xact_lock(hashtext('planning' || p_etab || p_lundi::text));

    DELETE FROM public.planning_publies
    WHERE etablissement = p_etab AND date_service BETWEEN p_lundi AND v_fin;

    INSERT INTO public.planning_publies
        (user_id, date_service, etablissement, nature, equipe, heure_debut, heure_fin, pause_minutes, poste)
    SELECT user_id, date_service, etablissement, nature, equipe, heure_debut, heure_fin, pause_minutes, poste
    FROM public.planning_shifts
    WHERE etablissement = p_etab AND date_service BETWEEN p_lundi AND v_fin;
    GET DIAGNOSTICS v_nb = ROW_COUNT;

    SELECT coalesce(max(version), 0) + 1 INTO v_version FROM public.planning_publications
    WHERE etablissement = p_etab AND semaine = p_lundi;

    INSERT INTO public.planning_publications (etablissement, semaine, version, nb_lignes, publie_par_id, publie_par_nom)
    VALUES (p_etab, p_lundi, v_version, v_nb, v_user.id, v_user.nom);

    -- Briefing, TAF et Rapport : a partir de la bascule seulement
    IF v_fin >= v_bascule THEN
        DELETE FROM public.planning_equipes
        WHERE etablissement = p_etab AND date BETWEEN greatest(p_lundi, v_bascule) AND v_fin;

        INSERT INTO public.planning_equipes
            (date, etablissement, employe_nom, employe_initiales, equipe, poste, heure_debut, heure_fin, service, notes)
        SELECT s.date_service, s.etablissement, u.nom, u.initiales, s.equipe, coalesce(s.poste, ''),
               s.heure_debut, s.heure_fin,
               CASE WHEN extract(hour FROM s.heure_fin) < extract(hour FROM s.heure_debut) THEN 'soir'
                    WHEN extract(hour FROM s.heure_debut) < 15 AND extract(hour FROM s.heure_fin) >= 19 THEN 'journee'
                    WHEN extract(hour FROM s.heure_fin) <= 18 THEN 'midi'
                    ELSE 'soir' END,
               CASE WHEN s.pause_minutes > 0 THEN 'pause ' || s.pause_minutes || 'mn' ELSE '' END
        FROM public.planning_publies s JOIN public.users u ON u.id = s.user_id
        WHERE s.etablissement = p_etab AND s.nature = 'travail'
          AND s.date_service BETWEEN greatest(p_lundi, v_bascule) AND v_fin
        ON CONFLICT DO NOTHING;
        GET DIAGNOSTICS v_miroir = ROW_COUNT;
    END IF;

    RETURN jsonb_build_object('version', v_version, 'lignes', v_nb, 'briefing_taf', v_miroir);
END $$;

-- ---------- Empreinte des horaires publies d un salarie sur une semaine ----------
CREATE OR REPLACE FUNCTION public.pbt_planning_empreinte(p_user uuid, p_lundi date)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    SELECT md5(coalesce(string_agg(
        concat_ws('/', date_service, etablissement, nature, heure_debut, heure_fin, pause_minutes),
        '|' ORDER BY date_service, heure_debut, nature, etablissement), ''))
    FROM public.planning_publies
    WHERE user_id = p_user AND date_service BETWEEN p_lundi AND p_lundi + 6;
$$;

-- ---------- Signature du salarie : son propre code est redemande ----------
CREATE OR REPLACE FUNCTION public.pbt_planning_signer(p_lundi date, p_pin text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $$
DECLARE
    v_user uuid := public.pbt_user_id();
    v_ip text := pbt_private.ip_client();
    v_contenu jsonb;
    v_empreinte text;
BEGIN
    IF v_user IS NULL THEN RAISE EXCEPTION 'session requise'; END IF;
    IF pbt_private.trop_de_tentatives('verif', v_ip) THEN
        PERFORM pbt_private.log_tentative('verif', false, NULL);
        RAISE EXCEPTION 'Trop de tentatives - reessaie dans 15 minutes';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pbt_private.user_pins
                   WHERE user_id = v_user AND pin_hash = pbt_private.hash_pin(p_pin)) THEN
        PERFORM pbt_private.log_tentative('verif', false, v_user);
        RAISE EXCEPTION 'Code incorrect';
    END IF;
    PERFORM pbt_private.log_tentative('verif', true, v_user);

    SELECT jsonb_agg(jsonb_build_object('date', date_service, 'etablissement', etablissement, 'nature', nature,
               'debut', heure_debut, 'fin', heure_fin, 'pause', pause_minutes) ORDER BY date_service, heure_debut)
    INTO v_contenu FROM public.planning_publies
    WHERE user_id = v_user AND date_service BETWEEN p_lundi AND p_lundi + 6;
    IF v_contenu IS NULL THEN RAISE EXCEPTION 'aucun planning publie pour cette semaine'; END IF;

    v_empreinte := public.pbt_planning_empreinte(v_user, p_lundi);
    INSERT INTO public.planning_signatures (user_id, semaine, empreinte, contenu)
    VALUES (v_user, p_lundi, v_empreinte, v_contenu)
    ON CONFLICT (user_id, semaine, empreinte) DO NOTHING;
    RETURN jsonb_build_object('signe', true);
END $$;

-- ---------- Etat des signatures d une semaine ----------
-- Un gestionnaire voit tous les salaries, un salarie ne voit que lui.
CREATE OR REPLACE FUNCTION public.pbt_planning_etat_signatures(p_lundi date)
RETURNS TABLE (user_id uuid, signe_le timestamptz, a_jour boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO '' AS $$
    WITH concernes AS (
        SELECT DISTINCT p.user_id FROM public.planning_publies p
        WHERE p.date_service BETWEEN p_lundi AND p_lundi + 6
          AND (public.pbt_planning_gestion() OR p.user_id = public.pbt_user_id())
    )
    SELECT c.user_id,
           (SELECT max(s.signe_le) FROM public.planning_signatures s
            WHERE s.user_id = c.user_id AND s.semaine = p_lundi),
           EXISTS (SELECT 1 FROM public.planning_signatures s
                   WHERE s.user_id = c.user_id AND s.semaine = p_lundi
                     AND s.empreinte = public.pbt_planning_empreinte(c.user_id, p_lundi))
    FROM concernes c;
$$;

REVOKE ALL ON FUNCTION public.pbt_planning_gestion() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pbt_planning_publier(text, date) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pbt_planning_empreinte(uuid, date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.pbt_planning_signer(date, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.pbt_planning_etat_signatures(date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.pbt_planning_gestion() TO authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_planning_publier(text, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_planning_signer(date, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.pbt_planning_etat_signatures(date) TO authenticated;

-- ---------- Modeles de depart : horaires les plus utilises dans Combo (60 derniers jours) ----------
INSERT INTO public.planning_modeles (etablissement, equipe, libelle, heure_debut, heure_fin, pause_minutes) VALUES
    ('freddy', 'cuisine', 'Matin',    '07:00', '15:00', 30),
    ('freddy', 'cuisine', 'Matin 2',  '07:30', '15:30', 30),
    ('freddy', 'cuisine', 'Journée',  '11:30', '21:30', 30),
    ('freddy', 'cuisine', 'Soir',     '15:00', '23:00', 30),
    ('freddy', 'cuisine', 'Soir long','15:00', '23:30', 30),
    ('freddy', 'plonge',  'Matin',    '09:00', '16:00', 30),
    ('freddy', 'plonge',  'Journée',  '12:00', '23:00', 30),
    ('freddy', 'plonge',  'Journée 2','11:30', '23:00', 45),
    ('freddy', 'plonge',  'Après-midi','14:00', '23:00', 30),
    ('freddy', 'plonge',  'Soir',     '17:00', '23:00', 30),
    ('freddy', 'salle',   'Midi',     '10:00', '17:00', 30),
    ('freddy', 'salle',   'Midi long','10:00', '18:00', 30),
    ('freddy', 'salle',   'Journée',  '11:30', '21:30', 30),
    ('freddy', 'salle',   'Après-midi','13:30', '23:00', 30),
    ('freddy', 'salle',   'Soir',     '18:00', '23:30', 20),
    ('liesel', 'cuisine', 'Matin',    '08:30', '16:00', 20),
    ('liesel', 'cuisine', 'Matin 2',  '09:00', '16:00', 20),
    ('liesel', 'cuisine', 'Journée',  '11:00', '22:00', 30),
    ('liesel', 'cuisine', 'Soir',     '15:30', '23:00', 30),
    ('liesel', 'cuisine', 'Soir 2',   '16:00', '23:00', 30),
    ('liesel', 'salle',   'Midi',     '10:30', '17:00', 30),
    ('liesel', 'salle',   'Midi long','10:30', '18:00', 30),
    ('liesel', 'salle',   'Midi soir','10:30', '18:30', 30),
    ('liesel', 'salle',   'Journée',  '11:30', '23:00', 30),
    ('liesel', 'salle',   'Soir',     '16:00', '23:00', 30)
ON CONFLICT (etablissement, equipe, heure_debut, heure_fin, pause_minutes) DO NOTHING;

-- ---------- Verification ----------
SELECT tablename, policyname, cmd FROM pg_policies WHERE tablename LIKE 'planning\_%' ORDER BY 1, 2;
