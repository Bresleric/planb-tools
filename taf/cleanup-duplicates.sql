-- Nettoyage des doublons dans predefined_tasks
-- Critère de doublon : même nom + même établissement
-- Conserve la ligne avec le plus petit id (= la plus ancienne) et supprime les autres
-- À exécuter dans Supabase SQL Editor

-- 1) Aperçu des doublons (à exécuter d'abord pour contrôle)
SELECT nom, etablissement, COUNT(*) AS nb_occurrences, array_agg(id ORDER BY id) AS ids
FROM predefined_tasks
GROUP BY nom, etablissement
HAVING COUNT(*) > 1
ORDER BY nb_occurrences DESC, nom;

-- 2) Suppression des doublons (garde le plus ancien id)
DELETE FROM predefined_tasks a
USING predefined_tasks b
WHERE a.id > b.id
  AND a.nom = b.nom
  AND a.etablissement IS NOT DISTINCT FROM b.etablissement;

-- 3) Vérification : ne doit plus retourner aucune ligne
SELECT nom, etablissement, COUNT(*) AS nb
FROM predefined_tasks
GROUP BY nom, etablissement
HAVING COUNT(*) > 1;
