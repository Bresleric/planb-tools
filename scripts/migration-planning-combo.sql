-- =============================================================================
-- Reflet automatique du planning Combo dans le module Planning (05/11/2026)
-- A coller dans Supabase -> SQL Editor. Script idempotent : relancable sans risque.
-- planning_combo est remplie par la fonction combo-planning (service role).
-- Elle est separee du brouillon : aucune synchronisation ne peut ecraser un essai.
-- La tache planifiee reprend l en-tete de combo-pointages-sync : pas de cle ici.
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.planning_combo (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES public.users(id),
    nom_combo text NOT NULL,
    date_service date NOT NULL,
    etablissement text NOT NULL REFERENCES public.etablissements(id),
    nature text NOT NULL DEFAULT 'travail',
    equipe text NOT NULL DEFAULT 'autre',
    heure_debut time NOT NULL,
    heure_fin time NOT NULL,
    pause_minutes integer NOT NULL DEFAULT 0,
    poste text,
    synchronise_le timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS planning_combo_etab_date ON public.planning_combo (etablissement, date_service);
CREATE INDEX IF NOT EXISTS planning_combo_user_date ON public.planning_combo (user_id, date_service);

ALTER TABLE public.planning_combo ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pbt_planning_gestion_lecture ON public.planning_combo;
CREATE POLICY pbt_planning_gestion_lecture ON public.planning_combo FOR SELECT TO authenticated
    USING ((select public.pbt_planning_gestion()));

-- Tache planifiee : 15 minutes apres combo-pointages-sync
DO $do$
DECLARE
    v_commande text;
BEGIN
    SELECT replace(command, 'functions/v1/combo-pointages', 'functions/v1/combo-planning')
    INTO v_commande FROM cron.job WHERE jobname = 'combo-pointages-sync';
    IF v_commande IS NULL THEN RAISE EXCEPTION 'tache combo-pointages-sync introuvable'; END IF;
    IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'combo-planning-sync') THEN
        PERFORM cron.unschedule('combo-planning-sync');
    END IF;
    PERFORM cron.schedule('combo-planning-sync', '20 0,1,5,9,13,17 * * *', v_commande);
END
$do$;

-- Verification
SELECT jobname, schedule FROM cron.job WHERE jobname = 'combo-planning-sync'
UNION ALL
SELECT tablename, policyname FROM pg_policies WHERE tablename = 'planning_combo';
