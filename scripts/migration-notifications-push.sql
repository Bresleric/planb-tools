-- ============================================================================
-- Notifications push — moteur de regles (12/10/2026)
-- Idempotent : rejouable sans risque.
--
-- Contenu :
--   1. notification_regles     : les regles (creneau horaire Paris, seuil,
--                                relance, cibles tablettes/telegram)
--   2. notifications_envoyees  : journal + anti-doublon (une ligne par
--                                evenement regle+etablissement+cle)
--   3. notif_evenements()      : LE MOTEUR — calcule les evenements du moment,
--                                reserve au service_role (edge function notif-push)
--   4. Les 8 regles validees par Eric
--
-- Le cron (toutes les 5 min -> notif-push {action: tick}) est dans un fichier
-- A PART (migration-notifications-cron.sql), a activer en DERNIER, apres le
-- test sur iPad.
-- Secrets requis cote edge function : VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY,
-- VAPID_SUBJECT (mailto:...). Jamais dans le repo.
-- ============================================================================

-- 1. Regles -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_regles (
  code            text PRIMARY KEY,
  libelle         text NOT NULL,
  description     text,
  actif           boolean NOT NULL DEFAULT true,
  etablissement   text CHECK (etablissement IN ('freddy', 'liesel')), -- NULL = les deux
  heure_debut     time NOT NULL,         -- heure de Paris
  heure_fin       time NOT NULL,
  seuil_minutes   integer,               -- selon la regle (duree, retard...)
  relance_minutes integer,               -- NULL = un seul envoi par evenement
  tablettes       boolean NOT NULL DEFAULT true,
  telegram        boolean NOT NULL DEFAULT true
);

ALTER TABLE notification_regles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON notification_regles;
CREATE POLICY pbt_session ON notification_regles FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

-- 2. Journal / anti-doublon ---------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications_envoyees (
  id               bigserial PRIMARY KEY,
  regle_code       text NOT NULL REFERENCES notification_regles(code),
  etablissement    text NOT NULL,
  cle              text NOT NULL,        -- identifie l evenement (id tache, date...)
  titre            text,
  corps            text,
  nb_appareils     integer DEFAULT 0,    -- abonnements vises au dernier envoi
  nb_envois        integer DEFAULT 1,    -- 1 + relances
  telegram         boolean DEFAULT false,
  premier_envoi_at timestamptz NOT NULL DEFAULT now(),
  dernier_envoi_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (regle_code, etablissement, cle)
);

ALTER TABLE notifications_envoyees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_session ON notifications_envoyees;
CREATE POLICY pbt_session ON notifications_envoyees FOR ALL TO authenticated
  USING ((select public.pbt_session_ok())) WITH CHECK ((select public.pbt_session_ok()));

-- 3. Le moteur ----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notif_evenements()
RETURNS TABLE(regle_code text, etablissement text, cle text, titre text, corps text, url text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $fn$
#variable_conflict use_column
DECLARE
  r RECORD;
  h_paris time := (now() AT TIME ZONE 'Europe/Paris')::time;
  auj date := (now() AT TIME ZONE 'Europe/Paris')::date;
BEGIN
  FOR r IN SELECT * FROM public.notification_regles
           WHERE actif AND h_paris >= heure_debut AND h_paris <= heure_fin
  LOOP

    IF r.code = 'production_non_terminee' THEN
      RETURN QUERY
      SELECT r.code, t.etablissement, t.id::text,
             'Production toujours en cours'::text,
             (t.tache || COALESCE(' (' || u.nom || ')', '') || ' : demarree il y a '
              || ((COALESCE(t.duree_accumulee_secondes, 0) + EXTRACT(EPOCH FROM now() - t.date_debut_execution))::int / 60)
              || ' min et pas terminee')::text,
             'taf/'::text
      FROM public.tasks t
      LEFT JOIN public.users u ON u.id = t.debut_par_id
      WHERE t.fait_par_id IS NULL AND t.date_debut_execution IS NOT NULL
        AND t.date_debut_execution > now() - interval '20 hours'
        AND (COALESCE(t.duree_accumulee_secondes, 0) + EXTRACT(EPOCH FROM now() - t.date_debut_execution)) >= r.seuil_minutes * 60
        AND (r.etablissement IS NULL OR t.etablissement = r.etablissement);

    ELSIF r.code = 'temperatures_manquantes' THEN
      RETURN QUERY
      SELECT r.code, x.etablissement, auj::text,
             'Temperatures non relevees'::text,
             (x.manquants || ' frigo' || CASE WHEN x.manquants > 1 THEN 's' ELSE '' END
              || ' sur ' || x.total || ' sans releve : ' || x.noms)::text,
             'temperatures/'::text
      FROM (
        SELECT f.etablissement,
               count(*) FILTER (WHERE NOT f.releve)::int AS manquants,
               count(*)::int AS total,
               left(string_agg(f.nom, ', ') FILTER (WHERE NOT f.releve), 180) AS noms
        FROM (
          SELECT g.etablissement, g.nom,
                 EXISTS (SELECT 1 FROM public.temp_releves rl WHERE rl.frigo_id = g.id AND rl.date = auj) AS releve
          FROM public.temp_frigos g WHERE g.actif
        ) f
        GROUP BY f.etablissement
      ) x
      WHERE x.manquants > 0 AND (r.etablissement IS NULL OR x.etablissement = r.etablissement);

    ELSIF r.code = 'briefing_midi' THEN
      RETURN QUERY
      WITH etabs AS (SELECT unnest(ARRAY['freddy', 'liesel']) AS etab),
      pub AS (
        SELECT b.etablissement, b.id FROM public.briefings b
        WHERE b.date = auj AND b.statut = 'publie'
          AND (b.type = 'jour' OR (b.type = 'service' AND b.service = 'midi'))
      )
      SELECT r.code, e.etab, (auj::text || '-pub'),
             'Briefing du midi'::text, 'Le briefing du jour n est pas encore publie'::text, 'briefing/'::text
      FROM etabs e LEFT JOIN pub p ON p.etablissement = e.etab
      WHERE p.id IS NULL AND (r.etablissement IS NULL OR e.etab = r.etablissement)
      UNION ALL
      SELECT r.code, p.etablissement, (auj::text || '-lect'),
             'Briefing du midi'::text, 'Le briefing est publie mais personne ne l a encore lu'::text, 'briefing/'::text
      FROM pub p
      WHERE NOT EXISTS (SELECT 1 FROM public.briefing_lectures l WHERE l.briefing_id = p.id)
        AND (r.etablissement IS NULL OR p.etablissement = r.etablissement);

    ELSIF r.code = 'briefing_soir' THEN
      -- Seulement la ou un briefing du soir existe ce jour-la
      RETURN QUERY
      SELECT r.code, b.etablissement, (auj::text || '-pub'),
             'Briefing du soir'::text, 'Le briefing du soir n est pas encore publie'::text, 'briefing/'::text
      FROM public.briefings b
      WHERE b.date = auj AND b.type = 'service' AND b.service = 'soir' AND b.statut <> 'publie'
        AND (r.etablissement IS NULL OR b.etablissement = r.etablissement)
      UNION ALL
      SELECT r.code, b.etablissement, (auj::text || '-lect'),
             'Briefing du soir'::text, 'Le briefing du soir est publie mais personne ne l a encore lu'::text, 'briefing/'::text
      FROM public.briefings b
      WHERE b.date = auj AND b.type = 'service' AND b.service = 'soir' AND b.statut = 'publie'
        AND NOT EXISTS (SELECT 1 FROM public.briefing_lectures l WHERE l.briefing_id = b.id)
        AND (r.etablissement IS NULL OR b.etablissement = r.etablissement);

    ELSIF r.code = 'dlc_lots' THEN
      -- DLC aujourd hui ou demain UNIQUEMENT (les DLC depassees sont du stock
      -- fantome : 333 lots jamais sortis -> spam garanti si on les inclut)
      RETURN QUERY
      SELECT r.code, x.etablissement, auj::text,
             'DLC a surveiller'::text,
             (x.nb || ' lot' || CASE WHEN x.nb > 1 THEN 's' ELSE '' END
              || ' avec DLC aujourd hui ou demain : ' || x.noms)::text,
             'stock/'::text
      FROM (
        SELECT s.etablissement, count(*)::int AS nb,
               left(string_agg(COALESCE(s.produit, s.article_nom), ', '), 180) AS noms
        FROM public.stock_par_lot s
        WHERE s.quantite_restante > 0 AND s.dlc >= auj AND s.dlc <= auj + 1
        GROUP BY s.etablissement
      ) x
      WHERE r.etablissement IS NULL OR x.etablissement = r.etablissement;

    ELSIF r.code = 'caisse_veille' THEN
      -- La saisie, pas la validation (caisse_controle.valide est toujours false)
      RETURN QUERY
      WITH etabs AS (SELECT unnest(ARRAY['freddy', 'liesel']) AS etab)
      SELECT r.code, e.etab, (auj - 1)::text,
             'Caisse non saisie'::text,
             ('La caisse du ' || to_char(auj - 1, 'DD/MM') || ' n est pas saisie')::text,
             'caisse/'::text
      FROM etabs e
      WHERE NOT EXISTS (SELECT 1 FROM public.caisse_controle c WHERE c.etablissement = e.etab AND c.date = auj - 1)
        AND (r.etablissement IS NULL OR e.etab = r.etablissement);

    ELSIF r.code = 'taf_matin' THEN
      -- Hors productions : 105 productions sont reportees de jour en jour
      -- (Knack MEP, Choucroute...) -> alerte permanente si on les compte
      RETURN QUERY
      SELECT r.code, x.etablissement, auj::text,
             'TAF du matin en retard'::text,
             (x.nb || ' tache' || CASE WHEN x.nb > 1 THEN 's' ELSE '' END
              || ' du matin pas faite' || CASE WHEN x.nb > 1 THEN 's' ELSE '' END || ' : ' || x.noms)::text,
             'taf/'::text
      FROM (
        SELECT t.etablissement, count(*)::int AS nb, left(string_agg(t.tache, ', '), 180) AS noms
        FROM public.tasks t
        WHERE t.creneau = 'Matin' AND t.fait_par_id IS NULL
          AND (t.echeance AT TIME ZONE 'Europe/Paris')::date = auj
          AND NOT COALESCE(t.is_production, false)
        GROUP BY t.etablissement
      ) x
      WHERE r.etablissement IS NULL OR x.etablissement = r.etablissement;

    ELSIF r.code = 'appro_urgent' THEN
      RETURN QUERY
      SELECT r.code, b.etablissement, b.id::text,
             'Besoin urgent en attente'::text,
             (COALESCE(b.article_nom, b.ingredient_nom, 'Article')
              || ' : demande urgente il y a ' || (EXTRACT(EPOCH FROM now() - b.date_demande)::int / 60) || ' min, toujours pas commandee')::text,
             'approvisionnement/'::text
      FROM public.appro_besoins b
      WHERE b.urgence AND b.statut = 'demande'
        AND b.date_demande < now() - make_interval(mins => r.seuil_minutes)
        AND b.date_demande > now() - interval '3 days'
        AND (r.etablissement IS NULL OR b.etablissement = r.etablissement);

    END IF;
  END LOOP;
END;
$fn$;

REVOKE ALL ON FUNCTION public.notif_evenements() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notif_evenements() TO service_role;

-- 4. Les regles validees par Eric ---------------------------------------------
INSERT INTO notification_regles (code, libelle, description, heure_debut, heure_fin, seuil_minutes, relance_minutes) VALUES
  ('production_non_terminee', 'Production non terminee',  'Une production demarree depuis plus de X min n est pas terminee', '06:00', '23:30', 180, NULL),
  ('temperatures_manquantes', 'Temperatures manquantes',  'Des frigos n ont pas de releve aujourd hui',                      '11:00', '22:00', NULL, 240),
  ('briefing_midi',           'Briefing du midi',         'Briefing du jour pas publie ou pas lu',                           '11:30', '14:00', NULL, NULL),
  ('briefing_soir',           'Briefing du soir',         'Briefing du soir pas publie ou pas lu (si prevu ce jour)',        '18:30', '21:00', NULL, NULL),
  ('dlc_lots',                'DLC a surveiller',         'Des lots en stock ont une DLC aujourd hui ou demain',             '09:00', '20:00', NULL, NULL),
  ('caisse_veille',           'Caisse de la veille',      'La caisse de la veille n est pas saisie',                         '12:00', '20:00', NULL, 240),
  ('taf_matin',               'TAF du matin',             'Des taches du matin (hors productions) ne sont pas faites',       '11:30', '14:00', NULL, NULL),
  ('appro_urgent',            'Besoin appro urgent',      'Un besoin urgent attend depuis plus de X min',                    '08:00', '22:00', 60,   NULL)
ON CONFLICT (code) DO NOTHING;

-- Verifications :
--   SELECT tablename, policyname FROM pg_policies WHERE tablename LIKE 'notification%';
--   SELECT code, actif, heure_debut, heure_fin FROM notification_regles ORDER BY code;
--   (en service_role) SELECT * FROM notif_evenements();
