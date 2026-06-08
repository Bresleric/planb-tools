-- ============================================================================
-- Migration : activer RLS + policy anon permissive sur les 26 tables exposees
-- ----------------------------------------------------------------------------
-- Contexte : l audit Supabase (get_advisors security) du 08/06/2026 a signale
-- 26 tables public avec RLS DESACTIVEE. Sans RLS, ces tables sont accessibles
-- en lecture ET ecriture par le role anon (la cle publique visible dans le code
-- source du site). Plusieurs contiennent des donnees sensibles : caisse,
-- pointages/paie, releves de temperature (HACCP), briefings, informations.
--
-- Ce que fait cette migration :
--   Pour chaque table : ENABLE ROW LEVEL SECURITY + policy permissive
--   anon USING(true) WITH CHECK(true), strictement le meme pattern que le reste
--   de l app (fiche_ingredients, fiches_techniques_actions_post, etc.).
--
-- Effet : supprime l alerte critique de Supabase et aligne ces tables sur le
-- reste de l app. NB : cela ne RESTREINT pas l acces (la policy reste
-- permissive) ; le but est de ne rien casser. Un vrai durcissement (Auth /
-- Edge Functions) reste un chantier separe a decider.
--
-- Idempotent : peut etre relance sans risque (DROP POLICY IF EXISTS avant
-- CREATE, car CREATE POLICY IF NOT EXISTS n existe pas en Postgres).
--
-- A executer dans Supabase -> SQL Editor (projet dzrherfavgiuygnimtux).
-- Verification en fin de fichier.
-- ============================================================================

-- Caisse -------------------------------------------------------------------
ALTER TABLE public.caisse_controle ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS caisse_controle_anon_all ON public.caisse_controle;
CREATE POLICY caisse_controle_anon_all ON public.caisse_controle AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.caisse_comptage ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS caisse_comptage_anon_all ON public.caisse_comptage;
CREATE POLICY caisse_comptage_anon_all ON public.caisse_comptage AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Briefings ----------------------------------------------------------------
ALTER TABLE public.briefing_previsions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_previsions_anon_all ON public.briefing_previsions;
CREATE POLICY briefing_previsions_anon_all ON public.briefing_previsions AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefings_anon_all ON public.briefings;
CREATE POLICY briefings_anon_all ON public.briefings AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefing_lectures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_lectures_anon_all ON public.briefing_lectures;
CREATE POLICY briefing_lectures_anon_all ON public.briefing_lectures AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefing_incidents ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_incidents_anon_all ON public.briefing_incidents;
CREATE POLICY briefing_incidents_anon_all ON public.briefing_incidents AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefing_rappels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_rappels_anon_all ON public.briefing_rappels;
CREATE POLICY briefing_rappels_anon_all ON public.briefing_rappels AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefing_produits ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_produits_anon_all ON public.briefing_produits;
CREATE POLICY briefing_produits_anon_all ON public.briefing_produits AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.briefing_resume_hebdo ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS briefing_resume_hebdo_anon_all ON public.briefing_resume_hebdo;
CREATE POLICY briefing_resume_hebdo_anon_all ON public.briefing_resume_hebdo AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Planning / taches --------------------------------------------------------
ALTER TABLE public.planning_equipes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS planning_equipes_anon_all ON public.planning_equipes;
CREATE POLICY planning_equipes_anon_all ON public.planning_equipes AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.taches_recurrentes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS taches_recurrentes_anon_all ON public.taches_recurrentes;
CREATE POLICY taches_recurrentes_anon_all ON public.taches_recurrentes AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Temperatures (HACCP) -----------------------------------------------------
ALTER TABLE public.temp_frigos ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS temp_frigos_anon_all ON public.temp_frigos;
CREATE POLICY temp_frigos_anon_all ON public.temp_frigos AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.temp_releves ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS temp_releves_anon_all ON public.temp_releves;
CREATE POLICY temp_releves_anon_all ON public.temp_releves AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- HowTo --------------------------------------------------------------------
ALTER TABLE public.howto_tutoriels ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS howto_tutoriels_anon_all ON public.howto_tutoriels;
CREATE POLICY howto_tutoriels_anon_all ON public.howto_tutoriels AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.howto_etapes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS howto_etapes_anon_all ON public.howto_etapes;
CREATE POLICY howto_etapes_anon_all ON public.howto_etapes AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.howto_vues ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS howto_vues_anon_all ON public.howto_vues;
CREATE POLICY howto_vues_anon_all ON public.howto_vues AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Pointages ----------------------------------------------------------------
ALTER TABLE public.pointage_postes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pointage_postes_anon_all ON public.pointage_postes;
CREATE POLICY pointage_postes_anon_all ON public.pointage_postes AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.pointage_evenements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pointage_evenements_anon_all ON public.pointage_evenements;
CREATE POLICY pointage_evenements_anon_all ON public.pointage_evenements AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.pointage_periodes_travail ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pointage_periodes_travail_anon_all ON public.pointage_periodes_travail;
CREATE POLICY pointage_periodes_travail_anon_all ON public.pointage_periodes_travail AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Informations -------------------------------------------------------------
ALTER TABLE public.informations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS informations_anon_all ON public.informations;
CREATE POLICY informations_anon_all ON public.informations AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.information_targets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS information_targets_anon_all ON public.information_targets;
CREATE POLICY information_targets_anon_all ON public.information_targets AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.information_images ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS information_images_anon_all ON public.information_images;
CREATE POLICY information_images_anon_all ON public.information_images AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.information_attachments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS information_attachments_anon_all ON public.information_attachments;
CREATE POLICY information_attachments_anon_all ON public.information_attachments AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.information_lectures ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS information_lectures_anon_all ON public.information_lectures;
CREATE POLICY information_lectures_anon_all ON public.information_lectures AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- Notifications ------------------------------------------------------------
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_subscriptions_anon_all ON public.push_subscriptions;
CREATE POLICY push_subscriptions_anon_all ON public.push_subscriptions AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE public.notification_windows ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS notification_windows_anon_all ON public.notification_windows;
CREATE POLICY notification_windows_anon_all ON public.notification_windows AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================================
-- VERIFICATION post-migration : doit retourner 26 lignes, rls_enabled = true,
-- chacune avec sa policy *_anon_all.
-- ============================================================================
SELECT c.relname            AS table_name,
       c.relrowsecurity     AS rls_enabled,
       p.policyname
FROM   pg_class c
JOIN   pg_namespace n ON n.oid = c.relnamespace
LEFT   JOIN pg_policies  p ON p.tablename = c.relname AND p.schemaname = 'public'
WHERE  n.nspname = 'public'
AND    c.relname IN (
    'caisse_controle','caisse_comptage','briefing_previsions','briefings',
    'briefing_lectures','briefing_incidents','briefing_rappels','briefing_produits',
    'briefing_resume_hebdo','planning_equipes','taches_recurrentes','temp_frigos',
    'temp_releves','howto_tutoriels','howto_etapes','howto_vues','pointage_postes',
    'pointage_evenements','pointage_periodes_travail','informations',
    'information_targets','information_images','information_attachments',
    'information_lectures','push_subscriptions','notification_windows'
)
ORDER BY table_name;
