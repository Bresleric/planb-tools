-- ============================================================
-- FIX : Erreur de sauvegarde du contrôle de caisse chez Liesel
-- ============================================================
-- Symptôme : LK reçoit "Erreur de sauvegarde" au moment d'enregistrer.
-- Cause    : la contrainte CHECK sur caisse_comptage.etablissement
--            n'autorise toujours que 'freddy' et 'bonbao' (alors que
--            la migration bonbao -> liesel a été faite ailleurs).
-- Vérifié  : 0 ligne 'bonbao' dans caisse_comptage, donc pas de
--            migration de données nécessaire — on remplace juste la
--            contrainte.
-- ============================================================

ALTER TABLE caisse_comptage
    DROP CONSTRAINT IF EXISTS caisse_comptage_etablissement_check;

ALTER TABLE caisse_comptage
    ADD CONSTRAINT caisse_comptage_etablissement_check
    CHECK (etablissement IN ('freddy', 'liesel'));

-- Vérification : doit afficher freddy/liesel
SELECT conname, pg_get_constraintdef(oid)
FROM pg_constraint
WHERE conrelid = 'public.caisse_comptage'::regclass
  AND conname = 'caisse_comptage_etablissement_check';
