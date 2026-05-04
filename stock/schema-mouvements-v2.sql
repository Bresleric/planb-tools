-- =============================================================================
-- Module Stock — Migration v2 : enrichir les vues stock_par_lot et stock_par_article
-- =============================================================================
-- Date : 2026-05-04
-- Ajoute les champs nécessaires à l'écran État du stock pour afficher
-- correctement les données après prise en compte des SORTIES.
--
-- À exécuter APRÈS schema-mouvements.sql.

-- DROP CASCADE car stock_par_article dépend de stock_par_lot
DROP VIEW IF EXISTS public.stock_par_article CASCADE;
DROP VIEW IF EXISTS public.stock_par_lot CASCADE;

-- =========================================================================
-- VUE : stock_par_lot — enrichie
-- =========================================================================
CREATE VIEW public.stock_par_lot AS
WITH agg AS (
  SELECT
    scan_tracabilite_id,
    SUM(CASE WHEN type = 'ENTREE'      THEN quantite ELSE 0 END) AS qte_entree,
    SUM(CASE WHEN type = 'SORTIE'      THEN quantite ELSE 0 END) AS qte_sortie,
    SUM(CASE WHEN type = 'AJUSTEMENT'  THEN quantite ELSE 0 END) AS qte_ajustement
  FROM public.stock_mouvements
  WHERE scan_tracabilite_id IS NOT NULL
  GROUP BY scan_tracabilite_id
)
SELECT
  t.id AS scan_tracabilite_id,
  t.scan_id,
  t.article_id,
  a.nom AS article_nom,
  a.categorie AS article_categorie,
  a.unite AS article_unite,
  s.etablissement,
  t.produit,
  t.lot,
  t.dlc,
  t.ddm,
  t.fabricant,
  t.origine,
  t.poids_net_kg AS quantite_initiale,
  COALESCE(g.qte_entree, 0)     AS qte_entree,
  COALESCE(g.qte_sortie, 0)     AS qte_sortie,
  COALESCE(g.qte_ajustement, 0) AS qte_ajustement,
  COALESCE(g.qte_entree, 0) - COALESCE(g.qte_sortie, 0) + COALESCE(g.qte_ajustement, 0) AS quantite_restante,
  s.storage_path,
  s.mime_type,
  s.created_at AS scan_at,
  s.created_by_nom AS scan_par
FROM public.scan_tracabilite t
JOIN public.scans s ON s.id = t.scan_id
JOIN public.appro_ingredients a ON a.id = t.article_id
LEFT JOIN agg g ON g.scan_tracabilite_id = t.id
WHERE t.article_id IS NOT NULL
  AND s.statut IN ('valide', 'en_attente_validation', 'extrait');

COMMENT ON VIEW public.stock_par_lot IS 'Stock courant par lot (entrée - sortie + ajustement) avec champs enrichis pour UI.';

-- =========================================================================
-- VUE : stock_par_article (recréée après DROP CASCADE)
-- =========================================================================
CREATE VIEW public.stock_par_article AS
SELECT
  article_id,
  article_nom,
  article_categorie,
  article_unite,
  etablissement,
  COUNT(*) FILTER (WHERE quantite_restante > 0)        AS nb_lots_dispo,
  COUNT(*) FILTER (WHERE quantite_restante <= 0)       AS nb_lots_epuises,
  SUM(quantite_restante)                                AS quantite_restante_total,
  MIN(dlc) FILTER (WHERE quantite_restante > 0)         AS dlc_min_dispo,
  MAX(scan_at)                                          AS dernier_scan_at
FROM public.stock_par_lot
GROUP BY article_id, article_nom, article_categorie, article_unite, etablissement;

COMMENT ON VIEW public.stock_par_article IS 'Agrégation du stock courant par article et établissement.';
