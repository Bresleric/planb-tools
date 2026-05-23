#!/bin/bash
# ============================================================
# Commit + push — Modale production : la liste des matieres
# premieres devient un RECAPITULATIF en lecture seule.
#  - quand les etiquettes sont scannees, plus rien a selectionner
#  - les lots decomptes du stock sont simplement affiches
#  - bouton « Ajuster les lots / quantites » pour les cas rares
#
# Modification DEJA appliquee dans le repo par Cowork
# (taf/index.html). Ce script ne fait que committer.
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche active : $(git branch --show-current) ==="

git add taf/index.html scripts/scan-recap-matieres.sh

echo ""
echo "=== Fichiers a committer ==="
git status --short taf/index.html scripts/scan-recap-matieres.sh
echo ""

git commit -m "feat(production): recap matieres en lecture seule apres scan

- La section « Matieres premieres utilisees » s'ouvre desormais
  en recapitulatif lecture seule : les lots issus des etiquettes
  scannees sont affiches, plus aucune selection a faire.
- Bouton « Ajuster les lots / quantites » pour basculer vers la
  selection manuelle (cas rares), et retour au recap.
- Supprime la redondance : scanner les etiquettes suffit."

echo ""
echo "=== Push ==="
git push

echo ""
echo "=== Termine OK ==="
