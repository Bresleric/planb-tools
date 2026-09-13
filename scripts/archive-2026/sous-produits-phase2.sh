#!/usr/bin/env bash
# Commit + push Phase 2 : declaration des sous-produits sur les fiches techniques
# Usage : bash scripts/sous-produits-phase2.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

echo "=== Fichiers concernes ==="
git add production/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "feat(production): Phase 2 sous-produits - declaration sur fiches techniques

Ajout dune section Sous-produits issus de cette production dans le formulaire
fiche technique (production/index.html). Permet de declarer N sous-produits cuits
issus dune meme production (ex: choucroute garnie -> lard, gendarmes, palette).

- Nouvelle section UI avec lignes dynamiques (nom, categorie, MP source crue,
  ratio cru->cuit, quantite estimee, unite, DLC jours/heures, temperature,
  conditionnement, article catalogue cuit optionnel)
- addSousProduitRow + chargement editFiche + reset resetForm
- DB.getSousProduits / DB.saveSousProduits (delete + insert)
- Extraction DOM et sauvegarde dans saveFiche apres saveActionsPost
- Bump service worker CACHE_NAME v5 -> v6"

git push origin main

echo "=== Termine ==="
