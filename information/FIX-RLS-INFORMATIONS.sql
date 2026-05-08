-- ============================================================================
-- FIX : Erreur "new row violates row-level security policy for table informations"
-- ============================================================================
-- Symptôme : au clic sur "Publier" dans le module information, l'app reçoit
--            'Erreur : new row violates row-level security policy for table "informations"'
--
-- Cause    : RLS est ACTIVÉE sur les 5 tables du module mais AUCUNE policy
--            n'est définie → toute opération est bloquée pour la clé anon.
--            Le schema.sql d'origine prévoyait pourtant RLS désactivée
--            (commentaire ligne 6 : "RLS : non activée (cohérent avec le
--            reste du projet, voir audit). Policies prêtes à activer une
--            fois Supabase Auth en place.").
--
-- Solution : désactiver RLS sur les 5 tables, conformément à la convention
--            du projet PlanB-Tools (auth maison par PIN, pas Supabase Auth,
--            donc auth.uid() est toujours NULL). Aligne le module information
--            sur les autres modules (caisse, taf, production, etc.).
--
-- À exécuter dans : Supabase Studio → SQL Editor → coller → Run
-- ============================================================================

ALTER TABLE informations             DISABLE ROW LEVEL SECURITY;
ALTER TABLE information_targets      DISABLE ROW LEVEL SECURITY;
ALTER TABLE information_images       DISABLE ROW LEVEL SECURITY;
ALTER TABLE information_attachments  DISABLE ROW LEVEL SECURITY;
ALTER TABLE information_lectures     DISABLE ROW LEVEL SECURITY;

-- Vérification : toutes les lignes doivent afficher rls_enabled = false
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN ('informations','information_targets','information_images',
                    'information_attachments','information_lectures')
ORDER BY c.relname;
