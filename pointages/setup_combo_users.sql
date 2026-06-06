-- ============================================================
-- SETUP USERS — Pré-requis pour l'import Combo
-- Date : 2026-06-06
-- ============================================================
-- Crée les 8 utilisateurs manquants détectés dans l'export Combo
-- (4 nouveaux vus en juin + 4 "historiques" non encore créés).
-- Corrige aussi les 2 typos qui empêcheraient le matching automatique.
--
-- ⚠️  IMPORTANT : Les PINs ci-dessous ont été générés aléatoirement.
-- Tu peux les changer si tu préfères, ou les transmettre aux salariés tels quels.
-- Eric complétera les autres champs RH (date_embauche, taux_horaire...) via Admin > Utilisateurs.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. CORRECTIONS DE TYPOS (pour matching Combo)
-- ============================================================

-- "Anne-Sopie Messin" → "Anne-Sophie Messin" (h manquant)
UPDATE users
SET nom = 'Anne-Sophie Messin'
WHERE nom = 'Anne-Sopie Messin';

-- "Bresler Eric" → "Eric Bresler" (ordre inversé)
UPDATE users
SET nom = 'Eric Bresler'
WHERE nom = 'Bresler Eric' AND role = 'admin';


-- ============================================================
-- 2. CRÉATION DES 8 NOUVEAUX USERS
-- ============================================================
-- Tous en rôle 'collaborateur' par défaut. Eric ajustera via Admin > Utilisateurs.
-- Le INSERT est protégé : si un user du même nom existe déjà, l'insertion est sautée.

-- Christelle Dix (33 services Combo jan-mai) — historique non créé
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Christelle Dix', 'CDx', '1409', 'collaborateur', 'freddy', ARRAY['freddy'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Christelle Dix');

-- Amauric Eberhart (20 services Combo) — historique non créé
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Amauric Eberhart', 'AE', '2679', 'collaborateur', 'freddy', ARRAY['freddy'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Amauric Eberhart');

-- Marion Raucy (15 services Combo) — historique non créé
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Marion Raucy', 'MaR', '2824', 'collaborateur', 'liesel', ARRAY['liesel'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Marion Raucy');

-- Rachel Ngomayi (16 services Combo) — historique non créé
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Rachel Ngomayi', 'RaN', '3286', 'collaborateur', 'liesel', ARRAY['liesel'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Rachel Ngomayi');

-- Agathe Lefranc (3 services soir Freddy juin) — nouvelle, extra ?
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Agathe Lefranc', 'AgL', '4657', 'collaborateur', 'freddy', ARRAY['freddy'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Agathe Lefranc');

-- Eoline Puthod (11 services Liesel) — nouvelle
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Eoline Puthod', 'EoP', '5012', 'collaborateur', 'liesel', ARRAY['liesel'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Eoline Puthod');

-- Laura Engel (20 services Freddy) — nouvelle, semble régulière
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Laura Engel', 'LaE', '5506', 'collaborateur', 'freddy', ARRAY['freddy'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Laura Engel');

-- Mathilde Boellinger (21 services Liesel) — nouvelle, semble régulière
INSERT INTO users (nom, initiales, code, role, etablissement, acces_etablissements, actif)
SELECT 'Mathilde Boellinger', 'MBo', '9935', 'collaborateur', 'liesel', ARRAY['liesel'], true
WHERE NOT EXISTS (SELECT 1 FROM users WHERE nom = 'Mathilde Boellinger');

COMMIT;


-- ============================================================
-- VÉRIFICATIONS
-- ============================================================

-- A) Les 2 corrections de typos ont été appliquées
SELECT nom, role FROM users
WHERE nom IN ('Anne-Sophie Messin', 'Eric Bresler', 'Anne-Sopie Messin', 'Bresler Eric')
ORDER BY nom;
-- Doit afficher : Anne-Sophie Messin + Eric Bresler (les anciens noms ne doivent plus apparaître)

-- B) Les 8 nouveaux users sont créés
SELECT nom, initiales, code, etablissement, actif FROM users
WHERE nom IN (
  'Christelle Dix', 'Amauric Eberhart', 'Marion Raucy', 'Rachel Ngomayi',
  'Agathe Lefranc', 'Eoline Puthod', 'Laura Engel', 'Mathilde Boellinger'
)
ORDER BY nom;

-- C) Compte total des users actifs (avant : 22, après : 30)
SELECT COUNT(*) AS nb_users_actifs FROM users WHERE actif = true;


-- ============================================================
-- PINS À TRANSMETTRE AUX SALARIÉS (à conserver !)
-- ============================================================
-- 1409 → Christelle Dix         (Freddy)
-- 2679 → Amauric Eberhart       (Freddy)
-- 2824 → Marion Raucy           (Liesel)
-- 3286 → Rachel Ngomayi         (Liesel)
-- 4657 → Agathe Lefranc         (Freddy)
-- 5012 → Eoline Puthod          (Liesel)
-- 5506 → Laura Engel            (Freddy)
-- 9935 → Mathilde Boellinger    (Liesel)
