-- ============================================================
-- MIGRATION v3 — Auto-fermeture nocturne des périodes orphelines
-- Date : 2026-05-14
-- Auteur : session Cowork "Build tracking module for PlanB-Tools"
-- ============================================================
--
-- CONTEXTE :
-- Bilan d'usage après 16 jours de production : 71% d'oublis fin de service
-- (82 périodes ouvertes sur 116). Les bons élèves Clara MATTER et Matthieu
-- PAULUS prouvent que c'est utilisable, mais la majorité oublie.
--
-- SOLUTION : un job pg_cron qui ferme automatiquement à 00:59 FR toutes les
-- périodes ouvertes de la veille avec une fin_service estimée à 23:59:59.
-- Le manager corrigera ensuite via le futur écran admin /admin/pointages.html.
--
-- IMPACT PlanB-Pilote (cf. INTERFACES.md) : la colonne `duree_travail_minutes`
-- ne sera plus à 0 mais à une valeur estimée. Pilote pourra arrêter en partie
-- son workaround `NOW() - debut_service` (sauf pour la journée en cours).
--
-- TIMEZONE : Supabase tourne en UTC. 23:59 UTC = 00:59 FR hiver (CET) /
-- 01:59 FR été (CEST). Tolérance +1h en été acceptable.
-- ============================================================

-- 1. Activer pg_cron (extension de scheduling PostgreSQL)
CREATE EXTENSION IF NOT EXISTS pg_cron;


-- 2. Fonction qui ferme les périodes ouvertes des jours passés
CREATE OR REPLACE FUNCTION pointage_close_orphan_periods()
RETURNS INTEGER AS $$
DECLARE
  v_count INTEGER;
  v_today_paris DATE;
BEGIN
  -- On calcule la date courante en heure de Paris pour éviter les pièges UTC
  v_today_paris := (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Paris')::date;

  WITH closed AS (
    UPDATE pointage_periodes_travail
    SET
      -- fin_service estimée = 23:59:59 du jour de service (heure de Paris)
      fin_service = ((date_service + INTERVAL '23 hours 59 minutes 59 seconds')::timestamp AT TIME ZONE 'Europe/Paris'),
      duree_pauses_minutes = COALESCE(duree_pauses_minutes, 0),
      statut = 'saisi',
      notes = COALESCE(notes || E'\n', '') ||
              '[Auto ' || v_today_paris || '] Ferme par cron nocturne. Heure de fin estimee a 23:59. A corriger par le manager si l''heure reelle est differente.',
      updated_at = NOW()
    WHERE fin_service IS NULL
      AND date_service < v_today_paris
    RETURNING id
  )
  SELECT COUNT(*) INTO v_count FROM closed;

  -- Log dans les logs Supabase pour traçabilité
  RAISE NOTICE 'pointage_close_orphan_periods: % periodes fermees le %', v_count, v_today_paris;

  RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION pointage_close_orphan_periods() IS
  'Ferme automatiquement les periodes de pointage ouvertes des jours passes. Executee tous les jours a 23:59 UTC (00:59 FR hiver / 01:59 FR ete) par pg_cron. Retourne le nombre de periodes fermees.';


-- 3. Programmer le job cron : tous les jours à 23:59 UTC
SELECT cron.schedule(
  'pointage_auto_close_orphans',
  '59 23 * * *',
  $sql$SELECT pointage_close_orphan_periods();$sql$
);


-- 4. Exécution manuelle initiale pour fermer les 82 périodes orphelines existantes
SELECT pointage_close_orphan_periods() AS nb_periodes_fermees;


-- ============================================================
-- VÉRIFICATIONS
-- ============================================================

-- A) Le job est bien planifié :
SELECT jobname, schedule, command, active
FROM cron.job
WHERE jobname = 'pointage_auto_close_orphans';

-- B) Plus aucune période ouverte des jours passés :
SELECT COUNT(*) AS nb_orphelins_restants
FROM pointage_periodes_travail
WHERE fin_service IS NULL
  AND date_service < (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Paris')::date;
-- Doit retourner 0.

-- C) Périodes fermées récemment (avec note auto) :
SELECT user_nom, date_service, debut_service, fin_service, notes
FROM pointage_periodes_travail
WHERE notes LIKE '%[Auto%Ferme par cron%'
ORDER BY date_service DESC, user_nom
LIMIT 20;
