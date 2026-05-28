#!/bin/bash
# ============================================================
# Fix: handler ?edit_fiche=<id> n'etait plus dans production/.
# Cause probable : ecrasement par un commit ulterieur d'une autre
# session. Re-injection du handler de facon plus robuste :
#  - init() lit edit_fiche au tout debut, memorise dans
#    window.__pendingEditFiche, nettoie l'URL.
#  - L'onglet initial est force a 'create' quand un edit est
#    en attente (evite le flash de l'onglet Productions).
#  - loadFiches, des qu'allFiches est peuple, declenche
#    editFiche(id) via setTimeout(0).
# ============================================================
set -e
cd ~/planb-tools

echo "=== Branche : $(git branch --show-current) ==="
echo ""

git add production/index.html scripts/edit-fiche-handler-fix.sh

echo "=== Fichiers a committer ==="
git status --short production/index.html scripts/edit-fiche-handler-fix.sh
echo ""

git commit -m "fix(production): handler ?edit_fiche robuste

Le handler ?edit_fiche=<id> ajoute dans b31a9bd a ete ecrase par
un commit ulterieur. Re-injection avec ces ameliorations :

- init() lit edit_fiche en debut de fonction et le memorise dans
  window.__pendingEditFiche, nettoie l'URL via replaceState.
- Quand __pendingEditFiche est present, l'onglet initial est
  force a 'create' (au lieu de 'productions' par defaut). Plus
  de flash de l'onglet Productions avant l'edition.
- loadFiches, des qu'allFiches est peuple, declenche editFiche
  via setTimeout(0). Si la fiche n'existe pas, toast d'erreur."

echo ""
echo "=== Push ==="
git push

echo "=== Termine OK ==="
