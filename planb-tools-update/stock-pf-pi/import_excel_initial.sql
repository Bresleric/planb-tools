-- ============================================================
-- IMPORT INITIAL — Stock PF/PI saisi dans Excel par Eric le 11/05/2026
-- À exécuter APRÈS schema.sql, seed_unites_contenants.sql, init_meubles.sql
-- Source : Stock PF et PI 20260511.xlsx
-- ============================================================
-- Mapping appliqué :
--   Pièce "Cuisine"      → CUISINE
--   Meuble "Frigo gauche"→ CUISINE GAUCHE (freddy)
--   Niveau "Haut"        → 4 (sur meuble 4 niveaux)
--   Contenant "GN 1/6 15"→ GN_1_6_150 (à confirmer : GN 1/6 hauteur 150mm)
--   Unité "Pièces"       → piece
--   Unité "%"            → pourcent
-- ============================================================
-- Rapprochement des fiches techniques :
--   Cervelas               → "Préparer cervelas" (mise_en_place)
--   Compotée de rhubarbe   → fiche_id NULL (pas de fiche dédiée, "Tailler rhubarbe" est en amont)
--   Tarte oignons Entrée   → "Tarte à l'oignon" (produit_fini)
--   Tarte oignons Plat     → "Tarte à l'oignon" (produit_fini)
--   Escalopes Fg poêlées   → "Poêler foie gras" (produit_intermediaire)
-- ============================================================

WITH
  meuble AS (SELECT id, nom, categorie FROM public.temp_frigos
              WHERE etablissement='freddy' AND nom='CUISINE GAUCHE' LIMIT 1),
  ct_gn16_150 AS (SELECT id, libelle FROM public.contenants WHERE code='GN_1_6_150')
INSERT INTO public.stock_pf_pi (
  fiche_id, produit_nom, produit_categorie,
  meuble_id, meuble_nom, piece, emplacement, niveau,
  contenant_id, contenant_libelle, unite, quantite,
  observations, etablissement, date_releve
)
SELECT * FROM (VALUES
  -- Cervelas : 24 pièces, pas de contenant
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Préparer cervelas' AND etablissement='freddy' LIMIT 1),
    'Cervelas', 'mise_en_place',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 24::numeric,
    'Import initial Excel 11/05/2026', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Compotée de rhubarbe : 60% bac
  (
    NULL,
    'Compotée de rhubarbe', NULL,
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    (SELECT id FROM ct_gn16_150), (SELECT libelle FROM ct_gn16_150),
    'pourcent', 0.6::numeric,
    'Import initial Excel 11/05/2026 — pas de fiche dédiée, à créer ?', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Tarte oignons Entrée : 10 pièces (1ère ligne)
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Tarte à l’oignon' AND etablissement='freddy' LIMIT 1),
    'Tarte oignons Entrée', 'produit_fini',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 10::numeric,
    'Import initial Excel 11/05/2026 — format Entrée', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Tarte oignons Plat : 7 pièces (1ère ligne)
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Tarte à l’oignon' AND etablissement='freddy' LIMIT 1),
    'Tarte oignons Plat', 'produit_fini',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 7::numeric,
    'Import initial Excel 11/05/2026 — format Plat', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Escalopes de Fg poêlées : 15 pièces
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Poêler foie gras' AND etablissement='freddy' LIMIT 1),
    'Escalopes de Fg poêlées', 'produit_intermediaire',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 15::numeric,
    'Import initial Excel 11/05/2026', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Tarte oignons Entrée : 7 pièces (2e ligne — autre lot ?)
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Tarte à l’oignon' AND etablissement='freddy' LIMIT 1),
    'Tarte oignons Entrée', 'produit_fini',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 7::numeric,
    'Import initial Excel 11/05/2026 — 2e lot', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  ),
  -- Tarte oignons Plat : 4 pièces (2e ligne — autre lot ?)
  (
    (SELECT id FROM public.fiches_techniques WHERE nom='Tarte à l’oignon' AND etablissement='freddy' LIMIT 1),
    'Tarte oignons Plat', 'produit_fini',
    (SELECT id FROM meuble), (SELECT nom FROM meuble), (SELECT categorie FROM meuble),
    'Porte', 4,
    NULL, NULL, 'piece', 4::numeric,
    'Import initial Excel 11/05/2026 — 2e lot', 'freddy', '2026-05-11 12:00:00+02'::timestamptz
  )
) AS v(fiche_id, produit_nom, produit_categorie,
       meuble_id, meuble_nom, piece, emplacement, niveau,
       contenant_id, contenant_libelle, unite, quantite,
       observations, etablissement, date_releve);

-- Vérification
SELECT produit_nom, meuble_nom, niveau, quantite, unite, contenant_libelle, observations
  FROM public.stock_pf_pi
  ORDER BY created_at DESC
  LIMIT 10;
