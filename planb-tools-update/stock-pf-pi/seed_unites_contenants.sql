-- ============================================================
-- SEED — Unités & Contenants
-- À exécuter APRÈS schema.sql
-- Idempotent : ON CONFLICT DO NOTHING
-- ============================================================

-- ============================================================
-- UNITÉS
-- ============================================================
INSERT INTO public.unites (code, libelle, symbole, type, ordre) VALUES
  -- Masse
  ('kg',       'Kilogramme',   'kg',  'masse',        10),
  ('g',        'Gramme',       'g',   'masse',        11),
  -- Volume
  ('L',        'Litre',        'L',   'volume',       20),
  ('cL',       'Centilitre',   'cL',  'volume',       21),
  ('mL',       'Millilitre',   'mL',  'volume',       22),
  -- Unitaire
  ('piece',    'Pièce',        'pcs', 'unitaire',     30),
  ('portion',  'Portion',      'port','unitaire',     31),
  ('douzaine', 'Douzaine',     'dz',  'unitaire',     32),
  -- Pourcentage (utile pour "fond de bac")
  ('pourcent', 'Pourcentage',  '%',   'pourcentage',  40),
  -- Autres
  ('plaque',   'Plaque',       'pl',  'autre',        50),
  ('botte',    'Botte',        'bot', 'autre',        51),
  ('sachet',   'Sachet',       'sch', 'autre',        52),
  ('boite',    'Boîte',        'bte', 'autre',        53)
ON CONFLICT (code) DO NOTHING;


-- ============================================================
-- CONTENANTS — Norme Gastronorm (GN)
-- Hauteurs standard : 20, 40, 65, 100, 150, 200 mm
-- Format : 1/1 (530x325), 1/2, 1/3, 1/4, 1/6, 1/9, 2/1, 2/3
-- Contenance théorique en litres (valeurs moyennes constructeur)
-- ============================================================

-- GN 1/1 (530 × 325 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_1_20',  'GN 1/1 — 20 mm',  'GN', '1/1', 20,   2.5, 100),
  ('GN_1_1_40',  'GN 1/1 — 40 mm',  'GN', '1/1', 40,   5.5, 101),
  ('GN_1_1_65',  'GN 1/1 — 65 mm',  'GN', '1/1', 65,   9.0, 102),
  ('GN_1_1_100', 'GN 1/1 — 100 mm', 'GN', '1/1', 100, 13.5, 103),
  ('GN_1_1_150', 'GN 1/1 — 150 mm', 'GN', '1/1', 150, 20.5, 104),
  ('GN_1_1_200', 'GN 1/1 — 200 mm', 'GN', '1/1', 200, 28.0, 105)
ON CONFLICT (code) DO NOTHING;

-- GN 1/2 (325 × 265 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_2_20',  'GN 1/2 — 20 mm',  'GN', '1/2', 20,   1.0, 110),
  ('GN_1_2_40',  'GN 1/2 — 40 mm',  'GN', '1/2', 40,   2.5, 111),
  ('GN_1_2_65',  'GN 1/2 — 65 mm',  'GN', '1/2', 65,   4.0, 112),
  ('GN_1_2_100', 'GN 1/2 — 100 mm', 'GN', '1/2', 100,  6.5, 113),
  ('GN_1_2_150', 'GN 1/2 — 150 mm', 'GN', '1/2', 150,  9.5, 114),
  ('GN_1_2_200', 'GN 1/2 — 200 mm', 'GN', '1/2', 200, 12.5, 115)
ON CONFLICT (code) DO NOTHING;

-- GN 1/3 (325 × 176 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_3_20',  'GN 1/3 — 20 mm',  'GN', '1/3', 20,   0.7, 120),
  ('GN_1_3_40',  'GN 1/3 — 40 mm',  'GN', '1/3', 40,   1.5, 121),
  ('GN_1_3_65',  'GN 1/3 — 65 mm',  'GN', '1/3', 65,   2.5, 122),
  ('GN_1_3_100', 'GN 1/3 — 100 mm', 'GN', '1/3', 100,  4.0, 123),
  ('GN_1_3_150', 'GN 1/3 — 150 mm', 'GN', '1/3', 150,  6.0, 124),
  ('GN_1_3_200', 'GN 1/3 — 200 mm', 'GN', '1/3', 200,  8.0, 125)
ON CONFLICT (code) DO NOTHING;

-- GN 1/4 (265 × 162 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_4_20',  'GN 1/4 — 20 mm',  'GN', '1/4', 20,   0.5, 130),
  ('GN_1_4_40',  'GN 1/4 — 40 mm',  'GN', '1/4', 40,   1.0, 131),
  ('GN_1_4_65',  'GN 1/4 — 65 mm',  'GN', '1/4', 65,   1.8, 132),
  ('GN_1_4_100', 'GN 1/4 — 100 mm', 'GN', '1/4', 100,  2.8, 133),
  ('GN_1_4_150', 'GN 1/4 — 150 mm', 'GN', '1/4', 150,  4.0, 134),
  ('GN_1_4_200', 'GN 1/4 — 200 mm', 'GN', '1/4', 200,  5.5, 135)
ON CONFLICT (code) DO NOTHING;

-- GN 1/6 (176 × 162 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_6_20',  'GN 1/6 — 20 mm',  'GN', '1/6', 20,   0.3, 140),
  ('GN_1_6_40',  'GN 1/6 — 40 mm',  'GN', '1/6', 40,   0.7, 141),
  ('GN_1_6_65',  'GN 1/6 — 65 mm',  'GN', '1/6', 65,   1.1, 142),
  ('GN_1_6_100', 'GN 1/6 — 100 mm', 'GN', '1/6', 100,  1.8, 143),
  ('GN_1_6_150', 'GN 1/6 — 150 mm', 'GN', '1/6', 150,  2.6, 144),
  ('GN_1_6_200', 'GN 1/6 — 200 mm', 'GN', '1/6', 200,  3.5, 145)
ON CONFLICT (code) DO NOTHING;

-- GN 1/9 (176 × 108 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_1_9_65',  'GN 1/9 — 65 mm',  'GN', '1/9', 65,   0.6, 150),
  ('GN_1_9_100', 'GN 1/9 — 100 mm', 'GN', '1/9', 100,  1.0, 151)
ON CONFLICT (code) DO NOTHING;

-- GN 2/1 (650 × 530 mm) — grand format
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_2_1_20',  'GN 2/1 — 20 mm',  'GN', '2/1', 20,   5.5, 160),
  ('GN_2_1_40',  'GN 2/1 — 40 mm',  'GN', '2/1', 40,  12.5, 161),
  ('GN_2_1_65',  'GN 2/1 — 65 mm',  'GN', '2/1', 65,  20.0, 162),
  ('GN_2_1_100', 'GN 2/1 — 100 mm', 'GN', '2/1', 100, 28.5, 163),
  ('GN_2_1_150', 'GN 2/1 — 150 mm', 'GN', '2/1', 150, 41.5, 164),
  ('GN_2_1_200', 'GN 2/1 — 200 mm', 'GN', '2/1', 200, 56.0, 165)
ON CONFLICT (code) DO NOTHING;

-- GN 2/3 (354 × 325 mm)
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  ('GN_2_3_20',  'GN 2/3 — 20 mm',  'GN', '2/3', 20,   1.8, 170),
  ('GN_2_3_40',  'GN 2/3 — 40 mm',  'GN', '2/3', 40,   4.0, 171),
  ('GN_2_3_65',  'GN 2/3 — 65 mm',  'GN', '2/3', 65,   6.0, 172),
  ('GN_2_3_100', 'GN 2/3 — 100 mm', 'GN', '2/3', 100,  9.0, 173),
  ('GN_2_3_150', 'GN 2/3 — 150 mm', 'GN', '2/3', 150, 13.5, 174),
  ('GN_2_3_200', 'GN 2/3 — 200 mm', 'GN', '2/3', 200, 18.0, 175)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- AUTRES CONTENANTS
-- ============================================================
INSERT INTO public.contenants (code, libelle, famille, format, hauteur_mm, contenance_l, ordre) VALUES
  -- Sachets sous vide (formats courants)
  ('SAC_VIDE_S',  'Sachet sous-vide S (200×300)', 'Sachet', 'S', NULL, NULL, 200),
  ('SAC_VIDE_M',  'Sachet sous-vide M (250×350)', 'Sachet', 'M', NULL, NULL, 201),
  ('SAC_VIDE_L',  'Sachet sous-vide L (300×400)', 'Sachet', 'L', NULL, NULL, 202),
  ('SAC_VIDE_XL', 'Sachet sous-vide XL (400×500)','Sachet', 'XL',NULL, NULL, 203),
  -- Seaux
  ('SEAU_5L',   'Seau 5 L',   'Seau', '5L',  NULL,  5,  210),
  ('SEAU_10L',  'Seau 10 L',  'Seau', '10L', NULL, 10,  211),
  ('SEAU_20L',  'Seau 20 L',  'Seau', '20L', NULL, 20,  212),
  -- Boîtes hermétiques
  ('BOITE_05L', 'Boîte hermétique 0,5 L', 'Boite', '0.5L', NULL, 0.5, 220),
  ('BOITE_1L',  'Boîte hermétique 1 L',   'Boite', '1L',   NULL, 1.0, 221),
  ('BOITE_2L',  'Boîte hermétique 2 L',   'Boite', '2L',   NULL, 2.0, 222),
  ('BOITE_5L',  'Boîte hermétique 5 L',   'Boite', '5L',   NULL, 5.0, 223),
  -- Plaques pâtissières
  ('PLAQUE_60_40', 'Plaque pâtissière 60×40', 'Plaque', '60x40', NULL, NULL, 230),
  ('PLAQUE_40_30', 'Plaque pâtissière 40×30', 'Plaque', '40x30', NULL, NULL, 231),
  -- Sans contenant (vrac, suspension, etc.)
  ('AUCUN',    'Sans contenant / vrac',  'Autre', NULL, NULL, NULL, 990)
ON CONFLICT (code) DO NOTHING;
