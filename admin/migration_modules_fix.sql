-- ============================================================
-- MIGRATION: Renommer 'kitchen-taf' → 'taf' dans acces_modules
-- A exécuter dans Supabase SQL Editor AVANT le déploiement
-- ============================================================

-- Vérifier d'abord les users concernés
-- SELECT id, nom, acces_modules FROM users WHERE acces_modules::text LIKE '%kitchen-taf%';

-- Remplacer kitchen-taf par taf dans le tableau JSONB acces_modules
UPDATE users
SET acces_modules = (
    SELECT array_to_json(
        ARRAY(
            SELECT CASE WHEN elem = 'kitchen-taf' THEN 'taf' ELSE elem END
            FROM unnest(
                ARRAY(SELECT jsonb_array_elements_text(to_jsonb(acces_modules)))
            ) AS elem
        )
    )::jsonb
)
WHERE acces_modules::text LIKE '%kitchen-taf%';

-- Vérification
-- SELECT id, nom, acces_modules FROM users WHERE acces_modules IS NOT NULL AND acces_modules::text != '[]' ORDER BY nom;
