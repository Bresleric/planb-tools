-- ============================================================================
-- Assainissement du stock matieres premieres (02/11/2026) - valide par Eric
-- Liste detaillee : docs/ASSAINISSEMENT-STOCK-2026-11.md
-- Idempotent : un lot deja solde (source_table = 'assainissement') est ignore.
-- Retour arriere : DELETE FROM stock_mouvements WHERE source_table = 'assainissement';
-- STATUT : EXECUTE via MCP le 02/11/2026.
-- ============================================================================

-- Cas A : lots a DLC depassee avec quantite restante > 0 -> ramenes a zero
INSERT INTO stock_mouvements (id, type, article_id, scan_tracabilite_id, quantite, unite, etablissement, motif, source_table, source_id, created_by_id, created_by_nom, created_by_initiales, created_at)
SELECT gen_random_uuid(), 'AJUSTEMENT', l.article_id, l.scan_tracabilite_id, -l.quantite_restante, l.article_unite, l.etablissement,
       'Assainissement stock 11/2026 valide par Eric - cas A : lot a DLC depassee jamais sorti (DLC ' || l.dlc || ')',
       'assainissement', l.scan_tracabilite_id, '680636af-5451-435d-827b-cf8a5a161bf3'::uuid, 'Eric Bresler', 'EB', now()
FROM stock_par_lot l
WHERE l.quantite_restante > 0.001 AND l.dlc < current_date
  AND NOT EXISTS (SELECT 1 FROM stock_mouvements m WHERE m.source_table = 'assainissement' AND m.source_id = l.scan_tracabilite_id);

-- Cas B : lots sans DLC lisible, scannes il y a plus de 45 jours -> ramenes a zero
INSERT INTO stock_mouvements (id, type, article_id, scan_tracabilite_id, quantite, unite, etablissement, motif, source_table, source_id, created_by_id, created_by_nom, created_by_initiales, created_at)
SELECT gen_random_uuid(), 'AJUSTEMENT', l.article_id, l.scan_tracabilite_id, -l.quantite_restante, l.article_unite, l.etablissement,
       'Assainissement stock 11/2026 valide par Eric - cas B : lot sans DLC scanne le ' || l.scan_at::date,
       'assainissement', l.scan_tracabilite_id, '680636af-5451-435d-827b-cf8a5a161bf3'::uuid, 'Eric Bresler', 'EB', now()
FROM stock_par_lot l
WHERE l.quantite_restante > 0.001 AND l.dlc IS NULL AND l.scan_at < current_date - 45
  AND NOT EXISTS (SELECT 1 FROM stock_mouvements m WHERE m.source_table = 'assainissement' AND m.source_id = l.scan_tracabilite_id);

-- Cas C : lots en negatif (sorties > entrees, bug d unite des sorties de production) -> ramenes a zero
INSERT INTO stock_mouvements (id, type, article_id, scan_tracabilite_id, quantite, unite, etablissement, motif, source_table, source_id, created_by_id, created_by_nom, created_by_initiales, created_at)
SELECT gen_random_uuid(), 'AJUSTEMENT', l.article_id, l.scan_tracabilite_id, -l.quantite_restante, l.article_unite, l.etablissement,
       'Assainissement stock 11/2026 valide par Eric - cas C : lot en negatif (erreur d unite des sorties)',
       'assainissement', l.scan_tracabilite_id, '680636af-5451-435d-827b-cf8a5a161bf3'::uuid, 'Eric Bresler', 'EB', now()
FROM stock_par_lot l
WHERE l.quantite_restante < -0.001
  AND NOT EXISTS (SELECT 1 FROM stock_mouvements m WHERE m.source_table = 'assainissement' AND m.source_id = l.scan_tracabilite_id);

-- Verification : doit renvoyer 0
-- SELECT count(*) FROM stock_par_lot WHERE quantite_restante <> 0 AND (dlc < current_date OR quantite_restante < 0 OR (dlc IS NULL AND scan_at < current_date - 45));
