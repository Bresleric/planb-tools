#!/bin/bash
# ============================================================
# Commit + push — Phase C : affichage des etiquettes / lots
# utilises dans la fiche etiquette du module Production
# (tracabilite HACCP).
#
# Les modifications de code sont DEJA appliquees dans le repo
# par Cowork (production/index.html). Ce script ne fait que
# committer et pousser.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add production/index.html scripts/scan-fefo-phase-c.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/scan-fefo-phase-c.sh
echo ""

git commit -m "feat(scan-fefo phase C): tracabilite des lots dans l'etiquette production

- showEtiquette : nouvelle section « Matieres premieres / lots utilises ».
- loadEtiquetteTrace() : lit les sorties de stock de la production
  (stock_mouvements) et les rapproche des etiquettes scannees
  (scan_tracabilite) pour afficher produit / lot / DLC / fabricant.
- Les lots dont la DLC est depassee sont signales en rouge.
- Boucle la continuite HACCP TAF -> Production (phases A, B-1, B-2, C)."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
