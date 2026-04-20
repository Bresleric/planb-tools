-- ============================================================
-- MODULE POINTAGES - Remplacement de Combo
-- PlanB Tools - Supabase Migration
-- Phase 1 : Fondations (salariés, postes, pointages bruts, périodes consolidées)
-- Date : 20 avril 2026
-- Conformité : L-GAV (CCT hôtellerie-restauration suisse) + LTr (archivage 5 ans)
-- ============================================================

-- ============================================================
-- 1. RÉFÉRENTIEL DES POSTES
-- ============================================================
CREATE TABLE IF NOT EXISTS pointage_postes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  nom TEXT NOT NULL,                                -- Ex: "Serveur", "Chef de rang"
  code TEXT NOT NULL,                               -- Ex: "SERV", "CHR" (usage technique court)
  equipe TEXT NOT NULL CHECK (equipe IN ('salle', 'cuisine', 'plonge', 'autre')),
  etablissement TEXT REFERENCES etablissements(id), -- NULL = poste commun aux 2 restos
  taux_horaire_brut_min NUMERIC,                    -- Grille salariale minimum (optionnel, pour alertes)
  actif BOOLEAN DEFAULT TRUE,
  ordre INTEGER DEFAULT 0,                          -- Ordre d'affichage
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(code, etablissement)
);

-- Seed data : postes standards (communs aux 2 restos, etablissement=NULL)
INSERT INTO pointage_postes (nom, code, equipe, ordre) VALUES
  ('Serveur', 'SERV', 'salle', 10),
  ('Runner', 'RUN', 'salle', 20),
  ('Chef de rang', 'CHR', 'salle', 30),
  ('Maître d''hôtel', 'MH', 'salle', 40),
  ('Barman', 'BAR', 'salle', 50),
  ('Cuisinier', 'CUIS', 'cuisine', 60),
  ('Chef de cuisine', 'CDC', 'cuisine', 70),
  ('Commis', 'COM', 'cuisine', 80),
  ('Plongeur', 'PLG', 'plonge', 90),
  ('Manager', 'MGR', 'autre', 100)
ON CONFLICT (code, etablissement) DO NOTHING;


-- ============================================================
-- 2. FICHES SALARIÉS (données RH)
-- ============================================================
CREATE TABLE IF NOT EXISTS pointage_salaries (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Identité
  nom TEXT NOT NULL,
  prenom TEXT NOT NULL,
  initiales TEXT,                                   -- Ex: "JD" (pour affichage compact)
  date_naissance DATE,
  sexe TEXT CHECK (sexe IN ('H', 'F', 'X')),
  nationalite TEXT,
  numero_avs TEXT,                                  -- AVS suisse (756.XXXX.XXXX.XX)
  permis_type TEXT,                                 -- B, C, G, L, etc. (pour étrangers)
  permis_valable_jusquau DATE,

  -- Coordonnées
  adresse TEXT,
  npa TEXT,                                         -- Code postal (Suisse)
  localite TEXT,
  telephone TEXT,
  email TEXT,
  contact_urgence_nom TEXT,
  contact_urgence_tel TEXT,

  -- Contrat
  date_embauche DATE NOT NULL,
  date_fin_contrat DATE,                            -- NULL si CDI
  type_contrat TEXT NOT NULL CHECK (type_contrat IN (
    'cdi_plein',      -- CDI temps plein (42h/sem L-GAV)
    'cdi_partiel',    -- CDI temps partiel
    'cdd',            -- CDD / saisonnier
    'extra'           -- Auxiliaire / extra / appel ponctuel
  )),
  heures_contractuelles_semaine NUMERIC DEFAULT 42, -- 42, 30, 20... ou 0 pour extras
  taux_horaire_brut NUMERIC,                        -- CHF/h (brut)
  salaire_mensuel_brut NUMERIC,                     -- Alternative au taux horaire pour mensualisés
  treizieme_mois BOOLEAN DEFAULT FALSE,
  vacances_jours_an INTEGER DEFAULT 25,             -- Jours de vacances annuels (min L-GAV = 25)

  -- Affectation
  poste_principal_id UUID REFERENCES pointage_postes(id),
  postes_secondaires UUID[],                        -- Tableau d'IDs postes (polyvalence)
  etablissement_principal TEXT NOT NULL REFERENCES etablissements(id),
  etablissements_autorises TEXT[],                  -- Ex: ['freddy','liesel'] si polyvalent

  -- Lien user PlanB-Tools (créé après la fiche salarié)
  user_id UUID,                                     -- Référence vers users.id (lien 1:1)

  -- Administratif
  iban TEXT,
  banque TEXT,
  caisse_lpp TEXT,                                  -- Nom de la caisse LPP/prévoyance
  caisse_maladie TEXT,
  numero_interne TEXT,                              -- Matricule interne éventuel
  photo_url TEXT,

  -- Statut
  actif BOOLEAN DEFAULT TRUE,
  date_sortie DATE,                                 -- Date effective de départ
  motif_sortie TEXT,
  notes TEXT,                                       -- Notes RH internes

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  cree_par_id UUID,
  cree_par_nom TEXT
);

CREATE INDEX IF NOT EXISTS idx_salaries_etab ON pointage_salaries(etablissement_principal);
CREATE INDEX IF NOT EXISTS idx_salaries_actif ON pointage_salaries(actif);
CREATE INDEX IF NOT EXISTS idx_salaries_user ON pointage_salaries(user_id);


-- ============================================================
-- 3. POINTAGES BRUTS (événements horodatés)
-- ============================================================
-- Un enregistrement par événement de pointage (badgeage)
-- 4 types d'événements : debut_service, debut_pause, fin_pause, fin_service
CREATE TABLE IF NOT EXISTS pointage_evenements (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  salarie_id UUID NOT NULL REFERENCES pointage_salaries(id) ON DELETE RESTRICT,
  salarie_nom TEXT NOT NULL,                        -- Dénormalisé pour historique (si renommage)

  type_evenement TEXT NOT NULL CHECK (type_evenement IN (
    'debut_service',
    'debut_pause',
    'fin_pause',
    'fin_service'
  )),

  horodatage TIMESTAMPTZ NOT NULL DEFAULT NOW(),    -- Moment exact du pointage
  date_service DATE NOT NULL,                       -- Date logique du service (pour regroupement)

  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  poste_id UUID REFERENCES pointage_postes(id),     -- Poste tenu ce service
  poste_nom TEXT,                                   -- Dénormalisé

  -- Traçabilité
  source TEXT NOT NULL DEFAULT 'tablette' CHECK (source IN (
    'tablette',        -- Pointage sur la tablette du resto
    'saisie_manuelle', -- Correction/ajout manuel par manager
    'import_combo'     -- Import depuis Combo (historique)
  )),
  device_id UUID,                                   -- Si tablette : ID du device
  corrige BOOLEAN DEFAULT FALSE,                    -- TRUE si événement corrigé a posteriori
  corrige_par_id UUID,
  corrige_par_nom TEXT,
  corrige_le TIMESTAMPTZ,
  motif_correction TEXT,
  commentaire TEXT,

  -- Période de travail associée (remplie après consolidation)
  periode_travail_id UUID,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_evt_salarie ON pointage_evenements(salarie_id);
CREATE INDEX IF NOT EXISTS idx_evt_date ON pointage_evenements(date_service);
CREATE INDEX IF NOT EXISTS idx_evt_etab ON pointage_evenements(etablissement);
CREATE INDEX IF NOT EXISTS idx_evt_periode ON pointage_evenements(periode_travail_id);


-- ============================================================
-- 4. PÉRIODES DE TRAVAIL (sessions consolidées avec workflow validation)
-- ============================================================
-- Une ligne = un service de travail (début→fin avec pauses)
-- Alimentée par consolidation des pointage_evenements
CREATE TABLE IF NOT EXISTS pointage_periodes_travail (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  salarie_id UUID NOT NULL REFERENCES pointage_salaries(id) ON DELETE RESTRICT,
  salarie_nom TEXT NOT NULL,

  date_service DATE NOT NULL,
  etablissement TEXT NOT NULL REFERENCES etablissements(id),
  poste_id UUID REFERENCES pointage_postes(id),
  poste_nom TEXT,

  -- Horaires consolidés
  debut_service TIMESTAMPTZ NOT NULL,
  fin_service TIMESTAMPTZ,                          -- NULL si service en cours
  duree_pauses_minutes INTEGER DEFAULT 0,           -- Somme des pauses (début→fin)
  duree_travail_minutes INTEGER GENERATED ALWAYS AS (
    CASE
      WHEN fin_service IS NOT NULL
      THEN EXTRACT(EPOCH FROM (fin_service - debut_service))::INTEGER / 60 - COALESCE(duree_pauses_minutes, 0)
      ELSE NULL
    END
  ) STORED,

  -- Workflow de validation (double) :
  -- 1. saisi (pointages bruts consolidés)
  -- 2. en_attente_manager (semaine clôturée, attend validation manager)
  -- 3. valide_manager (manager/épouse d'Eric a validé)
  -- 4. en_attente_salarie (récap envoyé au salarié pour validation)
  -- 5. valide_salarie (salarié a confirmé) → peut alimenter la paie
  -- 6. conteste (salarié conteste, retour au manager)
  statut TEXT NOT NULL DEFAULT 'saisi' CHECK (statut IN (
    'saisi',
    'en_attente_manager',
    'valide_manager',
    'en_attente_salarie',
    'valide_salarie',
    'conteste'
  )),

  -- Traçabilité validation manager
  valide_manager_par_id UUID,
  valide_manager_par_nom TEXT,
  valide_manager_le TIMESTAMPTZ,
  commentaire_manager TEXT,

  -- Traçabilité validation salarié
  valide_salarie_le TIMESTAMPTZ,
  commentaire_salarie TEXT,
  conteste_motif TEXT,

  -- Calculs L-GAV (remplis en Phase 4, laissés à NULL pour l'instant)
  heures_normales_minutes INTEGER,                  -- Heures dans le cadre contractuel
  heures_sup_minutes INTEGER,                       -- Heures supplémentaires (>42h/sem)
  majoration_nuit_minutes INTEGER,                  -- Heures de nuit (23h-6h)
  majoration_dimanche_minutes INTEGER,              -- Heures du dimanche
  majoration_ferie_minutes INTEGER,                 -- Heures jour férié

  -- Lien planning prévu (Phase 2)
  planning_id UUID,                                 -- Référence au créneau planifié
  ecart_planning_minutes INTEGER,                   -- Écart entre prévu et réalisé

  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_periode_salarie ON pointage_periodes_travail(salarie_id);
CREATE INDEX IF NOT EXISTS idx_periode_date ON pointage_periodes_travail(date_service);
CREATE INDEX IF NOT EXISTS idx_periode_etab ON pointage_periodes_travail(etablissement);
CREATE INDEX IF NOT EXISTS idx_periode_statut ON pointage_periodes_travail(statut);

-- Une seule période de travail "ouverte" (fin_service NULL) par salarié à la fois
CREATE UNIQUE INDEX IF NOT EXISTS idx_periode_ouverte_unique
  ON pointage_periodes_travail(salarie_id)
  WHERE fin_service IS NULL;


-- ============================================================
-- 5. TRIGGERS : updated_at auto
-- ============================================================
CREATE OR REPLACE FUNCTION pointage_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_salaries_updated ON pointage_salaries;
CREATE TRIGGER trg_salaries_updated
  BEFORE UPDATE ON pointage_salaries
  FOR EACH ROW EXECUTE FUNCTION pointage_set_updated_at();

DROP TRIGGER IF EXISTS trg_periodes_updated ON pointage_periodes_travail;
CREATE TRIGGER trg_periodes_updated
  BEFORE UPDATE ON pointage_periodes_travail
  FOR EACH ROW EXECUTE FUNCTION pointage_set_updated_at();


-- ============================================================
-- 6. RLS (Row Level Security) — à activer après tests
-- ============================================================
-- Pour l'instant : accès open (cohérent avec les autres modules)
-- À sécuriser en Phase 5 : un salarié ne voit que ses propres pointages,
-- un manager voit son établissement, admin voit tout.

-- ALTER TABLE pointage_salaries ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pointage_evenements ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pointage_periodes_travail ENABLE ROW LEVEL SECURITY;


-- ============================================================
-- NOTES DÉVELOPPEMENT
-- ============================================================
-- Phase 1 (actuelle) : cette migration crée les tables de base
-- Phase 2 : ajouter pointage_plannings + pointage_planning_creneaux
-- Phase 3 : ajouter pointage_conges_demandes + pointage_conges_soldes
-- Phase 4 : ajouter colonnes calcul L-GAV + table pointage_feries
-- Phase 5 : activer RLS + import données Combo
