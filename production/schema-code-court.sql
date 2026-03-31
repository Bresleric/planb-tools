-- ============================================================
-- PRODUCTION MODULE - Ajout code_court sur fiches_techniques
-- À exécuter dans Supabase SQL Editor
-- ============================================================

-- 1. Ajouter la colonne code_court
ALTER TABLE fiches_techniques ADD COLUMN IF NOT EXISTS code_court TEXT;

-- 2. Index unique par établissement
CREATE UNIQUE INDEX IF NOT EXISTS idx_fiches_code_court_etab
  ON fiches_techniques(code_court, etablissement)
  WHERE code_court IS NOT NULL AND actif = true;

-- 3. Générer des codes courts pour les fiches existantes
-- Algorithme : 2 premières lettres de chaque mot significatif du nom
DO $$
DECLARE
  r RECORD;
  v_code TEXT;
  v_base TEXT;
  v_suffix INTEGER;
  v_exists BOOLEAN;
BEGIN
  FOR r IN
    SELECT id, nom, etablissement
    FROM fiches_techniques
    WHERE code_court IS NULL AND actif = true
    ORDER BY created_at
  LOOP
    -- Générer un code de base (4 premiers caractères des consonnes ou du nom)
    v_base := UPPER(LEFT(REGEXP_REPLACE(
      REGEXP_REPLACE(r.nom, '\m(de|du|des|le|la|les|au|aux|en|et|à|a|un|une|avec)\M', '', 'gi'),
      '[^A-Za-zÀ-ÿ]', '', 'g'
    ), 4));

    IF LENGTH(v_base) < 2 THEN
      v_base := 'XX' || LEFT(UPPER(r.nom), 2);
    END IF;

    v_base := LEFT(v_base || 'XXXX', 4);
    v_code := v_base;
    v_suffix := 2;

    -- Vérifier unicité et incrémenter si besoin
    LOOP
      SELECT EXISTS(
        SELECT 1 FROM fiches_techniques
        WHERE code_court = v_code AND etablissement = r.etablissement AND id != r.id
      ) INTO v_exists;

      EXIT WHEN NOT v_exists;
      v_code := LEFT(v_base, 3) || v_suffix::TEXT;
      v_suffix := v_suffix + 1;
      EXIT WHEN v_suffix > 9;
    END LOOP;

    UPDATE fiches_techniques SET code_court = v_code WHERE id = r.id;
  END LOOP;
END $$;

-- 4. Vérification
SELECT id, nom, code_court, etablissement
FROM fiches_techniques
WHERE actif = true
ORDER BY etablissement, nom;
