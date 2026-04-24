-- ============================================================
-- MIGRATION v2 — Refonte modèle Pointages (23 avril 2026)
-- Abandon de pointage_salaries → utilisation directe de users
-- ============================================================
-- Eric a clarifié : pas de tablette banalisée, pas de double PIN.
-- Le salarié utilise PlanB-Tools normalement avec son code utilisateur.
-- La table pointage_salaries devient inutile.
--
-- ⚠️  ATTENTION : cette migration SUPPRIME pointage_salaries et toutes
-- les données qu'elle contient (24 lignes importées depuis Combo).
-- C'est OK car les 20 personnes utiles sont déjà dans users.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. SUPPRIMER LES FK existantes vers pointage_salaries
-- ============================================================
ALTER TABLE pointage_evenements
  DROP CONSTRAINT IF EXISTS pointage_evenements_salarie_id_fkey;

ALTER TABLE pointage_periodes_travail
  DROP CONSTRAINT IF EXISTS pointage_periodes_travail_salarie_id_fkey;

-- Supprimer aussi l'index unique "1 période ouverte par salarié"
DROP INDEX IF EXISTS idx_periode_ouverte_unique;


-- ============================================================
-- 2. RENOMMER les colonnes salarie_* → user_*
-- ============================================================
-- pointage_evenements
ALTER TABLE pointage_evenements RENAME COLUMN salarie_id TO user_id;
ALTER TABLE pointage_evenements RENAME COLUMN salarie_nom TO user_nom;

-- pointage_periodes_travail
ALTER TABLE pointage_periodes_travail RENAME COLUMN salarie_id TO user_id;
ALTER TABLE pointage_periodes_travail RENAME COLUMN salarie_nom TO user_nom;


-- ============================================================
-- 3. AJOUTER les nouvelles FK vers users
-- ============================================================
-- ON DELETE SET NULL pour préserver l'historique si un user est supprimé
ALTER TABLE pointage_evenements
  ADD CONSTRAINT pointage_evenements_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE pointage_periodes_travail
  ADD CONSTRAINT pointage_periodes_travail_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

-- Recréer l'index unique sur user_id (1 période ouverte max par user)
CREATE UNIQUE INDEX IF NOT EXISTS idx_periode_ouverte_unique
  ON pointage_periodes_travail(user_id)
  WHERE fin_service IS NULL;

-- Renommer aussi les autres index pour cohérence
DROP INDEX IF EXISTS idx_evt_salarie;
DROP INDEX IF EXISTS idx_periode_salarie;
CREATE INDEX IF NOT EXISTS idx_evt_user ON pointage_evenements(user_id);
CREATE INDEX IF NOT EXISTS idx_periode_user ON pointage_periodes_travail(user_id);


-- ============================================================
-- 4. SUPPRIMER la table pointage_salaries (devenue inutile)
-- ============================================================
DROP TABLE IF EXISTS pointage_salaries CASCADE;


-- ============================================================
-- 5. ADAPTER pointage_evenements pour les nouvelles règles
-- ============================================================
-- Le poste tenu n'est plus systématique (en V2, on ne demande pas le poste à chaque pointage)
-- Mais on garde le champ disponible au cas où on l'utilise plus tard.

-- Pour l'instant, rien à modifier sur pointage_postes (toujours utilisable comme référentiel)


COMMIT;

-- ============================================================
-- VÉRIFICATIONS
-- ============================================================
-- Lance ces requêtes après pour vérifier que tout est OK :

-- 1) La table pointage_salaries n'existe plus :
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pointage_salaries';
-- (doit retourner 0 ligne)

-- 2) Les colonnes user_id existent et FK OK :
-- SELECT column_name, data_type FROM information_schema.columns
--  WHERE table_name = 'pointage_evenements' AND column_name LIKE 'user%';

-- 3) Combien de pointages dans la base (devrait être 0 puisqu'on n'a pas encore commencé) :
-- SELECT COUNT(*) FROM pointage_evenements;
-- SELECT COUNT(*) FROM pointage_periodes_travail;
