-- Simplification : une seule table de tâches prédéfinies, partagée entre Freddy et Liesel
-- 1) Aperçu : doublons par nom seul (peu importe l'établissement)
SELECT LOWER(TRIM(nom)) AS nom_norm, COUNT(*) AS nb, array_agg(id ORDER BY id) AS ids, array_agg(etablissement ORDER BY id) AS etabs
FROM predefined_tasks
GROUP BY LOWER(TRIM(nom))
HAVING COUNT(*) > 1
ORDER BY nb DESC, nom_norm;

-- 2) Fusion des doublons : garde le plus ancien id pour chaque nom (insensible casse/espaces)
DELETE FROM predefined_tasks a
USING predefined_tasks b
WHERE a.id > b.id
  AND LOWER(TRIM(a.nom)) = LOWER(TRIM(b.nom));

-- 3) Supprimer la notion d'établissement : tout passe à NULL
UPDATE predefined_tasks SET etablissement = NULL WHERE etablissement IS NOT NULL;

-- 4) Vérification finale
SELECT COUNT(*) AS total, COUNT(DISTINCT LOWER(TRIM(nom))) AS noms_distincts
FROM predefined_tasks;
