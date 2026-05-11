-- ============================================================
-- STOCK PF/PI — Schéma Supabase
-- Stock des Produits Finis (PF) et Produits Intermédiaires (PI)
-- Branché sur : etablissements, temp_frigos (meubles), fiches_techniques (produits)
-- Nouvelles tables : unites, contenants, stock_pf_pi
-- Date : 2026-05-11
-- ============================================================

-- ============================================================
-- 1) Table de référence : unités
-- ============================================================
CREATE TABLE IF NOT EXISTS public.unites (
  code text PRIMARY KEY,
  libelle text NOT NULL,
  symbole text NOT NULL,
  type text NOT NULL CHECK (type IN ('masse','volume','unitaire','pourcentage','autre')),
  ordre int NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.unites IS
  'Référentiel des unités (kg, L, pièce, %, etc.) utilisé par stock_pf_pi, productions, fiches_techniques.';

-- ============================================================
-- 2) Table de référence : contenants (GN, bacs, sachets, ...)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.contenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  libelle text NOT NULL,
  famille text NOT NULL CHECK (famille IN ('GN','Bac','Sachet','Seau','Boite','Plaque','Autre')),
  format text,           -- '1/1','1/2','1/3','1/4','1/6','1/9','2/1','2/3' pour GN
  hauteur_mm int,        -- 20, 40, 65, 100, 150, 200 pour GN
  contenance_l numeric,  -- volume théorique en litres
  ordre int NOT NULL DEFAULT 0,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.contenants IS
  'Nomenclature des contenants : GN 1/9 à 2/1 toutes hauteurs, bacs plastique, sachets sous vide, seaux, boîtes hermétiques, plaques pâtissières.';

CREATE INDEX IF NOT EXISTS contenants_famille_ordre_idx ON public.contenants(famille, ordre);

-- ============================================================
-- 3) Étendre temp_frigos avec nb_niveaux (max 4)
-- ============================================================
ALTER TABLE public.temp_frigos
  ADD COLUMN IF NOT EXISTS nb_niveaux int NOT NULL DEFAULT 1
    CHECK (nb_niveaux BETWEEN 1 AND 4);

COMMENT ON COLUMN public.temp_frigos.nb_niveaux IS
  'Nombre de niveaux/étagères du meuble (1 à 4). Convention stock_pf_pi : 1 = bas, 4 = haut.';

-- ============================================================
-- 4) Table principale : stock_pf_pi
-- ============================================================
CREATE TABLE IF NOT EXISTS public.stock_pf_pi (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Lien produit (fiche technique)
  fiche_id uuid REFERENCES public.fiches_techniques(id) ON DELETE SET NULL,
  produit_nom text NOT NULL,            -- snapshot résilient
  produit_categorie text,                -- 'produit_fini' | 'produit_intermediaire' | 'mise_en_place'

  -- Localisation
  meuble_id uuid REFERENCES public.temp_frigos(id) ON DELETE SET NULL,
  meuble_nom text NOT NULL,              -- snapshot résilient
  piece text NOT NULL,                   -- 'CUISINE' | 'LABO' | 'CAVE' | 'SALLE' | 'BAR' (= temp_frigos.categorie)
  emplacement text,                      -- 'Porte', 'Étagère', 'Tiroir' (libre)
  niveau int CHECK (niveau BETWEEN 1 AND 4),  -- 1=bas, 4=haut

  -- Conditionnement
  contenant_id uuid REFERENCES public.contenants(id) ON DELETE SET NULL,
  contenant_libelle text,                -- snapshot
  unite text REFERENCES public.unites(code) ON DELETE SET NULL,
  quantite numeric NOT NULL DEFAULT 0,

  -- Métadonnées
  observations text,
  etablissement text NOT NULL REFERENCES public.etablissements(id),

  -- Lien optionnel vers la production source
  production_id uuid REFERENCES public.productions(id) ON DELETE SET NULL,
  dlc date,

  -- Traçabilité du relevé
  date_releve timestamptz NOT NULL DEFAULT now(),
  releve_par_id uuid REFERENCES public.users(id) ON DELETE SET NULL,
  releve_par_nom text,
  releve_par_initiales text,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.stock_pf_pi IS
  'Stock courant des Produits Finis et Produits Intermédiaires par meuble/niveau/contenant. Saisi par relevé manuel depuis l''onglet Stock PF/PI du Module Production.';

CREATE INDEX IF NOT EXISTS stock_pf_pi_etab_meuble_idx ON public.stock_pf_pi(etablissement, meuble_id);
CREATE INDEX IF NOT EXISTS stock_pf_pi_fiche_idx ON public.stock_pf_pi(fiche_id);
CREATE INDEX IF NOT EXISTS stock_pf_pi_date_releve_idx ON public.stock_pf_pi(date_releve DESC);
CREATE INDEX IF NOT EXISTS stock_pf_pi_dlc_idx ON public.stock_pf_pi(dlc) WHERE dlc IS NOT NULL;

-- Trigger updated_at
CREATE OR REPLACE FUNCTION public.set_stock_pf_pi_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END$$;

DROP TRIGGER IF EXISTS trg_stock_pf_pi_updated_at ON public.stock_pf_pi;
CREATE TRIGGER trg_stock_pf_pi_updated_at
  BEFORE UPDATE ON public.stock_pf_pi
  FOR EACH ROW EXECUTE FUNCTION public.set_stock_pf_pi_updated_at();

-- ============================================================
-- 5) RLS (cohérent avec le reste de la base : permissif, géré côté app via PIN)
-- ============================================================
ALTER TABLE public.unites      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contenants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_pf_pi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS unites_all      ON public.unites;
DROP POLICY IF EXISTS contenants_all  ON public.contenants;
DROP POLICY IF EXISTS stock_pf_pi_all ON public.stock_pf_pi;

CREATE POLICY unites_all      ON public.unites      FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY contenants_all  ON public.contenants  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY stock_pf_pi_all ON public.stock_pf_pi FOR ALL USING (true) WITH CHECK (true);
