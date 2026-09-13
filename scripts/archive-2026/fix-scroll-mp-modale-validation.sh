#!/usr/bin/env bash
# Fix UX : liste des matieres premieres scrollable dans la modale de validation
# pour que le bouton Enregistrer reste accessible quand la fiche a 12+ ingredients.
# Usage : bash scripts/fix-scroll-mp-modale-validation.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add production/index.html taf/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "fix(ux): liste MP scrollable dans modale de validation production

Quand une fiche a beaucoup de matieres premieres (ex: choucroute garnie, 12+
ingredients), la liste debordait et le bouton Enregistrer devenait inaccessible.

- pd-matieres-list (production directe) et prod-matieres-list (validation TAF):
  max-height 40vh + overflow-y auto + bordure + padding pour delimiter le scroll
- production-modal modal-box (production): ajout max-height 90vh + overflow-y auto
  pour que tous les champs restent scrollables (la modale TAF scrollait deja)
- Bump service worker CACHE_NAME v6 -> v7"

git push origin main

echo "=== Termine ==="
