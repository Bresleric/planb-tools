-- ============================================================
-- MIGRATION v4 — Tables combo_pointages + combo_user_mapping + vue unifiée
-- Date : 2026-06-06
-- Auteur : session Cowork "Build tracking module for PlanB-Tools"
-- ============================================================
--
-- OBJECTIF :
-- Importer les données de pointage depuis Combo (application externe officielle
-- jusqu'à la bascule prévue au 01/07/2026) vers Supabase pour :
--   1. Préparer la bascule (archivage de l'historique RH)
--   2. Cross-checker avec les pointages natifs PlanB-Tools
--   3. Alimenter PlanB-Pilote avec une vue unifiée
--
-- ARCHITECTURE :
--   - Table combo_pointages : 1 ligne = 1 service d'1 personne d'1 jour.
--     3 niveaux d'information : planifié / pointé (réel saisi par salarié) / validé (corrigé par manager).
--   - Table combo_user_mapping : correspondance nom Combo ↔ user_id PlanB-Tools.
--     Pré-remplie avec les 30 noms connus au 06/06/2026.
--   - Vue pointages_unifies : UNION de pointage_periodes_travail (natif) et combo_pointages (validé).
--     Consommée par PlanB-Pilote.
--
-- IMPACT INTERFACES.md : ajouter combo_pointages, combo_user_mapping, pointages_unifies
-- au contrat avec PlanB-Pilote.
-- ============================================================

BEGIN;

-- ============================================================
-- 1. TABLE combo_user_mapping
-- ============================================================
CREATE TABLE IF NOT EXISTS combo_user_mapping (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  combo_collaborateur_nom TEXT NOT NULL UNIQUE,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  match_method TEXT DEFAULT 'manual'
    CHECK (match_method IN ('manual', 'auto_exact', 'auto_typo', 'auto_fuzzy', 'pending')),
  match_confidence NUMERIC,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE combo_user_mapping IS
  'Mapping noms Combo (CSV) ↔ users PlanB-Tools. user_id NULL = collaborateur Combo sans compte PBT (extras refusés à la création).';


-- ============================================================
-- 2. TABLE combo_pointages
-- ============================================================
CREATE TABLE IF NOT EXISTS combo_pointages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Identifiants extraits du CSV Combo
  date_service DATE NOT NULL,
  etablissement_combo TEXT NOT NULL,         -- Brut Combo (ex: "Chez  l oncle Freddy")
  etablissement TEXT NOT NULL                 -- Mappé : freddy / liesel
    CHECK (etablissement IN ('freddy', 'liesel')),
  equipe_combo TEXT,                          -- Brut Combo (ex: "Salle ")
  equipe TEXT,                                -- Normalisée : salle / cuisine / plonge

  collaborateur_nom_combo TEXT NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,

  -- Niveau 1 : planifié (le planning prévu)
  debut_planifie TIMESTAMPTZ,
  fin_planifiee TIMESTAMPTZ,
  pauses_planifiees_minutes INTEGER DEFAULT 0,

  -- Niveau 2 : pointé (le réel saisi par le salarié sur Combo)
  debut_pointe TIMESTAMPTZ,
  fin_pointee TIMESTAMPTZ,
  pauses_pointees_minutes INTEGER DEFAULT 0,

  -- Niveau 3 : validé (le corrigé par le manager — source de vérité paie)
  debut_valide TIMESTAMPTZ,
  fin_validee TIMESTAMPTZ,
  pauses_validees_minutes INTEGER DEFAULT 0,

  -- Durée travaillée effective (calculée auto à partir du validé)
  duree_travail_minutes INTEGER GENERATED ALWAYS AS (
    CASE
      WHEN debut_valide IS NOT NULL AND fin_validee IS NOT NULL THEN
        GREATEST(0, (EXTRACT(EPOCH FROM (fin_validee - debut_valide))::INTEGER / 60) - COALESCE(pauses_validees_minutes, 0))
      ELSE NULL
    END
  ) STORED,

  -- Validation
  valide_par_nom TEXT,

  -- Commentaires
  commentaire_debut_pointe TEXT,
  commentaire_fin_pointee TEXT,
  commentaire_validation TEXT,

  -- Traçabilité de l'import
  import_fichier_nom TEXT,
  import_date_traitement TIMESTAMPTZ DEFAULT NOW(),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  -- Clé naturelle : permet UPSERT idempotent (réimport sans doublons)
  UNIQUE(date_service, collaborateur_nom_combo, etablissement_combo, debut_planifie)
);

COMMENT ON TABLE combo_pointages IS
  '1 ligne = 1 service Combo (1 salarié, 1 jour, 1 resto, 1 plage horaire). Contient les 3 niveaux planifie/pointe/valide. Source de vérité pour paie = le valide. Importé via combo_import.py.';

CREATE INDEX IF NOT EXISTS idx_combo_pointages_date ON combo_pointages(date_service);
CREATE INDEX IF NOT EXISTS idx_combo_pointages_user ON combo_pointages(user_id);
CREATE INDEX IF NOT EXISTS idx_combo_pointages_etab_date ON combo_pointages(etablissement, date_service);


-- ============================================================
-- 3. PRÉ-REMPLISSAGE de combo_user_mapping (30 mappings connus)
-- ============================================================
-- Pour chaque nom Combo, on cherche le user_id par nom PlanB-Tools correspondant.
-- Si match exact : user_id rempli. Si pas trouvé : user_id = NULL (à traiter manuellement).
-- Les 4 extras refusés (Clotilde, Emilie, Etienne, Vianney, éléonore) ne sont PAS
-- mappés ici : ils auront user_id NULL dans combo_pointages.

WITH mapping AS (
  SELECT * FROM (VALUES
    ('Agathe Lefranc',                  'Agathe Lefranc',                  'auto_exact'),
    ('Alemoujrodo Koffi Noussoukpoe',   'Alemoujrodo Koffi NOUSSOUKPOE',   'auto_typo'),
    ('Amauric Eberhart',                'Amauric Eberhart',                'auto_exact'),
    ('Anne Sophie Messin',              'Anne-Sophie Messin',              'auto_typo'),
    ('Bresler Eric',                    'Eric Bresler',                    'auto_typo'),
    ('Camille Bresler',                 'Camille BRESLER',                 'auto_typo'),
    ('Carole Duarte',                   'Carole DUARTE',                   'auto_typo'),
    ('Charlotte Mc Closkey',            'Charlotte MC CLOSKEY',            'auto_typo'),
    ('Christelle Dix',                  'Christelle Dix',                  'auto_exact'),
    ('Clara Matter',                    'Clara MATTER',                    'auto_typo'),
    ('David Rouillaux',                 'David ROUILLAUX',                 'auto_typo'),
    ('Emilienne Ngo',                   'Emilienne NGO',                   'auto_typo'),
    ('Eoline Puthod',                   'Eoline Puthod',                   'auto_exact'),
    ('Eve Lhopiteau',                   'EVE Lhopiteau',                   'auto_typo'),
    ('Francesca Nutini',                'Francesca NUTINI',                'auto_typo'),
    ('Jean Alejandro Penalver',         'Jean Alejandro PENALVER',         'auto_typo'),
    ('Johnny Bauer',                    'Johnny Bauer',                    'auto_exact'),
    ('Laszlo Suhail Bustamante Carpio', 'Laszlo Suhail BUSTAMANTE CARPIO', 'auto_typo'),
    ('Laura Engel',                     'Laura Engel',                     'auto_exact'),
    ('Laurence Kohler',                 'Laurence KOHLER',                 'auto_typo'),
    ('Marine Merkiled Athanase',        'Marine MERKILED ATHANASE',        'auto_typo'),
    ('Marion Raucy',                    'Marion Raucy',                    'auto_exact'),
    ('Martine Oswald',                  'Martine OSWALD',                  'auto_typo'),
    ('Mathilde Balas',                  'Mathilde Balas',                  'auto_exact'),
    ('Mathilde Boellinger',             'Mathilde Boellinger',             'auto_exact'),
    ('Matthieu Paulus',                 'Matthieu PAULUS',                 'auto_typo'),
    ('Rachel Ngomayi',                  'Rachel Ngomayi',                  'auto_exact'),
    ('Tesfamariam Zeray Aregay',        'Tesfamariam ZERAY AREGAY',        'auto_typo'),
    ('Virginie Mohr',                   'Virginie Mohr',                   'auto_exact')
  ) AS m(combo_nom, users_nom, method)
)
INSERT INTO combo_user_mapping (combo_collaborateur_nom, user_id, match_method, notes)
SELECT
  m.combo_nom,
  u.id,
  m.method,
  'Auto-créé par migration v4 le 2026-06-06'
FROM mapping m
LEFT JOIN users u ON u.nom = m.users_nom
WHERE NOT EXISTS (
  SELECT 1 FROM combo_user_mapping cum WHERE cum.combo_collaborateur_nom = m.combo_nom
);


-- ============================================================
-- 4. VUE pointages_unifies (consommée par PlanB-Pilote)
-- ============================================================
-- Combine les pointages natifs PlanB-Tools (validés) avec les pointages Combo (validés).
-- Pour la période où Combo est encore officiel (jusqu'au 01/07/2026), Pilote
-- prendra prioritairement les données 'combo' (source de vérité).
-- Après bascule, on filtrera sur 'planb-tools' uniquement.

CREATE OR REPLACE VIEW pointages_unifies AS
SELECT
  'planb-tools'::TEXT AS source,
  pt.id::TEXT AS source_id,
  pt.user_id,
  pt.user_nom,
  pt.date_service,
  pt.etablissement,
  NULL::TEXT AS equipe,
  pt.debut_service AS debut,
  pt.fin_service AS fin,
  pt.duree_pauses_minutes,
  pt.duree_travail_minutes,
  pt.statut,
  NULL::TEXT AS valide_par_nom,
  pt.notes AS commentaire
FROM pointage_periodes_travail pt
WHERE pt.fin_service IS NOT NULL

UNION ALL

SELECT
  'combo'::TEXT AS source,
  cp.id::TEXT AS source_id,
  cp.user_id,
  cp.collaborateur_nom_combo AS user_nom,
  cp.date_service,
  cp.etablissement,
  cp.equipe,
  cp.debut_valide AS debut,
  cp.fin_validee AS fin,
  cp.pauses_validees_minutes AS duree_pauses_minutes,
  cp.duree_travail_minutes,
  'valide_combo'::TEXT AS statut,
  cp.valide_par_nom,
  cp.commentaire_validation AS commentaire
FROM combo_pointages cp
WHERE cp.debut_valide IS NOT NULL AND cp.fin_validee IS NOT NULL;

COMMENT ON VIEW pointages_unifies IS
  'UNION des pointages natifs PlanB-Tools (terminés) et Combo (validés). Source = "planb-tools" ou "combo". Consommée par PlanB-Pilote pour les indicateurs RH agrégés.';


-- ============================================================
-- 5. TRIGGER updated_at sur les nouvelles tables
-- ============================================================
DROP TRIGGER IF EXISTS trg_combo_pointages_updated ON combo_pointages;
CREATE TRIGGER trg_combo_pointages_updated
  BEFORE UPDATE ON combo_pointages
  FOR EACH ROW EXECUTE FUNCTION pointage_set_updated_at();

DROP TRIGGER IF EXISTS trg_combo_mapping_updated ON combo_user_mapping;
CREATE TRIGGER trg_combo_mapping_updated
  BEFORE UPDATE ON combo_user_mapping
  FOR EACH ROW EXECUTE FUNCTION pointage_set_updated_at();


-- ============================================================
-- 6. RLS — règle PBT non-négociable (cf CLAUDE.md, incident 31/05/2026)
-- ============================================================
-- Toute nouvelle table doit avoir RLS active + policy permissive anon,
-- sinon lectures vides silencieuses cote front (anon) et PlanB-Pilote.
-- L'import Python utilise la service_role key (bypass RLS) : non impacte.

ALTER TABLE combo_pointages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS combo_pointages_anon_all ON combo_pointages;
CREATE POLICY combo_pointages_anon_all ON combo_pointages
  AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);

ALTER TABLE combo_user_mapping ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS combo_user_mapping_anon_all ON combo_user_mapping;
CREATE POLICY combo_user_mapping_anon_all ON combo_user_mapping
  AS PERMISSIVE FOR ALL TO anon USING (true) WITH CHECK (true);


COMMIT;


-- ============================================================
-- VÉRIFICATIONS
-- ============================================================

-- A) Les 2 nouvelles tables et la vue sont créées
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('combo_pointages', 'combo_user_mapping', 'pointages_unifies')
ORDER BY table_name;
-- Attendu : 3 lignes

-- B) Combien de mappings ont trouvé un user_id valide ?
SELECT
  COUNT(*) AS total_mappings,
  COUNT(user_id) AS mappings_avec_user,
  COUNT(*) - COUNT(user_id) AS mappings_sans_user
FROM combo_user_mapping;
-- Attendu : 29 total, 29 avec user_id (tous matchés grâce au setup_combo_users.sql)

-- C) Liste détaillée du mapping pour Eric
SELECT
  cum.combo_collaborateur_nom,
  u.nom AS user_nom_pbt,
  u.etablissement AS user_etab,
  u.role AS user_role,
  cum.match_method
FROM combo_user_mapping cum
LEFT JOIN users u ON u.id = cum.user_id
ORDER BY cum.combo_collaborateur_nom;

-- D) RLS bien active + policies presentes sur les 2 nouvelles tables
SELECT tablename, policyname FROM pg_policies
WHERE tablename IN ('combo_pointages', 'combo_user_mapping')
ORDER BY tablename;
-- Attendu : 2 lignes (1 policy anon_all par table)
