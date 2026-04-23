-- ============================================================
-- Sous-module ELIS (Réceptions) - Schéma SQL + Seed référentiel
-- Suivi des mouvements linge/vêtements/sanitaire avec le prestataire ELIS
-- A exécuter dans Supabase SQL Editor
-- ============================================================

-- 1. Référentiel des articles ELIS
-- ============================================================
CREATE TABLE IF NOT EXISTS elis_articles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    pdl TEXT,                          -- Point de livraison ELIS (65138, 67967, 68085, ...)
    service TEXT NOT NULL,             -- Linge-Service | Habillement-Porteur | Habillement-Groupe | Sanitaire | Sol-Service
    nom TEXT NOT NULL,
    stock_theorique INTEGER DEFAULT 0, -- Stock de référence (feuille Référentiel Excel)
    pu_ht_hebdo NUMERIC(10,3) DEFAULT 0,
    frequence TEXT,                    -- Hebdo | Mensuel | 2 chgts/sem | 4 chgts/sem | 60 rech/mois | ...
    ordre INTEGER DEFAULT 0,
    actif BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (etablissement, nom)
);
CREATE INDEX IF NOT EXISTS idx_elis_articles_etab ON elis_articles(etablissement, actif, ordre);
CREATE INDEX IF NOT EXISTS idx_elis_articles_service ON elis_articles(etablissement, service);

-- 2. Mouvements ELIS (inventaire ou passage du livreur)
-- ============================================================
CREATE TABLE IF NOT EXISTS elis_mouvements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('inventaire', 'passage')),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    etablissement TEXT NOT NULL REFERENCES etablissements(id),
    bon_livraison TEXT,                -- N° BL ELIS (pour un passage)
    observation TEXT,
    user_id UUID NOT NULL,
    user_nom TEXT NOT NULL,
    user_initiales TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_elis_mouvements_date ON elis_mouvements(date, etablissement);
CREATE INDEX IF NOT EXISTS idx_elis_mouvements_type ON elis_mouvements(type, etablissement);

-- 3. Lignes de mouvement (une ligne par article × mouvement)
-- ============================================================
CREATE TABLE IF NOT EXISTS elis_mouvements_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mouvement_id UUID NOT NULL REFERENCES elis_mouvements(id) ON DELETE CASCADE,
    article_id UUID NOT NULL REFERENCES elis_articles(id),
    qty_retour INTEGER,                -- Sale à retourner (inventaire) OU retourné (passage)
    qty_livre INTEGER,                 -- Livré par ELIS (passage uniquement)
    qty_stock INTEGER,                 -- Stock propre présent après comptage
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (mouvement_id, article_id)
);
CREATE INDEX IF NOT EXISTS idx_elis_lignes_mouvement ON elis_mouvements_lignes(mouvement_id);
CREATE INDEX IF NOT EXISTS idx_elis_lignes_article ON elis_mouvements_lignes(article_id);

-- ============================================================
-- RLS Policies (public via anon key, comme le reste du module)
-- ============================================================
ALTER TABLE elis_articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE elis_mouvements ENABLE ROW LEVEL SECURITY;
ALTER TABLE elis_mouvements_lignes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public_all" ON elis_articles;
DROP POLICY IF EXISTS "public_all" ON elis_mouvements;
DROP POLICY IF EXISTS "public_all" ON elis_mouvements_lignes;
CREATE POLICY "public_all" ON elis_articles FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON elis_mouvements FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "public_all" ON elis_mouvements_lignes FOR ALL USING (true) WITH CHECK (true);

-- ============================================================
-- SEED : référentiel articles (source : Excel Fiche suivi ELIS, avril 2026)
-- ============================================================

-- Chez Oncle Freddy (PDL 65138 cuisine+groupé+sanitaire+sol, 68085 salle)
INSERT INTO elis_articles (etablissement, pdl, service, nom, stock_theorique, pu_ht_hebdo, frequence, ordre) VALUES
  ('freddy', '65138', 'Linge-Service',        'Tablier Plonge lourd',                        15,  1.273, 'Hebdo',            10),
  ('freddy', '65138', 'Linge-Service',        'Torchon Elis blc 50x66',                     196,  0.347, 'Hebdo',            11),
  ('freddy', '65138', 'Linge-Service',        'Sac textile elis gris polyester',              2,  0.326, 'Hebdo',            12),
  ('freddy', '65138', 'Habillement-Porteur',  'Veste Origin Access noir PC (P1, P2)',         5,  4.700, '2 chgts/sem',      20),
  ('freddy', '65138', 'Habillement-Porteur',  'Veste F Allure blanc PC Stretch (P3)',         5,  6.343, '2 chgts/sem',      21),
  ('freddy', '65138', 'Habillement-Porteur',  'Veste Origin elite H blc Bio CP (P5)',         5,  5.990, '2 chgts/sem',      22),
  ('freddy', '65138', 'Habillement-Porteur',  'Polo Everywear noir CP (P6)',                  5,  0.000, '2 chgts/sem',      23),
  ('freddy', '68085', 'Habillement-Porteur',  'Polo Essentials noir PC (12 porteurs P1-P12)', 9,  5.972, '4 chgts/sem',      24),
  ('freddy', '65138', 'Habillement-Groupe',   'Tablier bav. Rio beige PC',                   28,  0.339, 'Hebdo',            30),
  ('freddy', '65138', 'Habillement-Groupe',   'Le petit Tablier Jeans CP',                   48,  0.301, 'Hebdo',            31),
  ('freddy', '65138', 'Sanitaire',            'EM Papier Easyroll Aqualine (distributeur)',   2,  0.000, '2 distributeurs',  40),
  ('freddy', '65138', 'Sanitaire',            'Rech. Essuie-Main Easyroll blch (recharges)', 60,  0.000, '60 rech/mois',     41),
  ('freddy', '65138', 'Sanitaire',            'Sèche-Mains air pulse Dyson V gris',           2,  0.000, '2 distributeurs',  42),
  ('freddy', '65138', 'Sanitaire',            'Distrib. Savon B1000 Aqualine (+ recharges)',  2, 19.290, '2 rech/mois',      43),
  ('freddy', '65138', 'Sanitaire',            'Distrib. PH400 Aqualine (+ recharges)',        2,  0.000, '2 rech/mois',      44),
  ('freddy', '65138', 'Sol-Service',          'Tapis ergonomique 60x90',                      2,  8.004, 'Mensuel',          50),
  ('freddy', '65138', 'Sol-Service',          'Tapis STRG / ONCLE 80x80 PT',                  1, 28.470, 'Mensuel',          51)
ON CONFLICT (etablissement, nom) DO UPDATE SET
  pdl = EXCLUDED.pdl,
  service = EXCLUDED.service,
  stock_theorique = EXCLUDED.stock_theorique,
  pu_ht_hebdo = EXCLUDED.pu_ht_hebdo,
  frequence = EXCLUDED.frequence,
  ordre = EXCLUDED.ordre,
  actif = true;

-- Chez Tante Liesel (PDL 67967)
INSERT INTO elis_articles (etablissement, pdl, service, nom, stock_theorique, pu_ht_hebdo, frequence, ordre) VALUES
  ('liesel', '67967', 'Linge-Service', 'Nappe ronsard blc 18x18',             15,  4.406, 'Hebdo',          10),
  ('liesel', '67967', 'Linge-Service', 'Serv. Table ronsard PTE 55x55 blc',  750,  0.369, 'Hebdo',          11),
  ('liesel', '67967', 'Linge-Service', 'Torchon Elis blc 50x66',             300,  0.347, 'Hebdo',          12),
  ('liesel', '67967', 'Sol-Service',   'Tapis TANTE LIESEL 80x80 PT',          1, 28.470, 'Hebdo (1x/sem)', 50)
ON CONFLICT (etablissement, nom) DO UPDATE SET
  pdl = EXCLUDED.pdl,
  service = EXCLUDED.service,
  stock_theorique = EXCLUDED.stock_theorique,
  pu_ht_hebdo = EXCLUDED.pu_ht_hebdo,
  frequence = EXCLUDED.frequence,
  ordre = EXCLUDED.ordre,
  actif = true;

-- ============================================================
-- Vérification
-- ============================================================
-- SELECT etablissement, service, COUNT(*) FROM elis_articles GROUP BY etablissement, service ORDER BY etablissement, service;
-- SELECT * FROM elis_articles ORDER BY etablissement, ordre;
