#!/usr/bin/env bash
# Phase 3 (b) : validation production directe avec sous-produits (mere + N filles).
# Perimetre : production/index.html (flow production directe uniquement). TAF = commit (c).
# Usage : bash scripts/sous-produits-phase3b-prod-directe.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add production/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "feat(production): Phase 3b production directe multi sous-produits

A la validation d une production directe, si la fiche declare des sous-produits,
bascule en mode multi : N etiquettes au lieu d une. Mono inchange.

- Detection : getSousProduitsCached (cache module) lit fiches_techniques_sous_produits
- UI : section Sous-produits a etiqueter (blocs nom/qty/unite/DLC editables) ;
  en multi on masque qty/DLC globaux, on garde categorie/observation/actions-post
- Pre-remplissage : computeSousProduitQtys somme les poids_net_kg scannes par
  article (principal + lots supplementaires) x ratio_transformation, sinon estimee
- Validation pdSaveProductionWrapper : cree 1 mere (qty 1, unite production,
  DLC la plus longue des filles) + N filles (parent_production_id, qty/unite/DLC
  propres). Sorties stock + cloture tache sur la mere uniquement
- Redirection multi vers ?prod_id=MERE&action=etiquette -> PDF N pages (commit a)
- Non-regression : fiche sans sous-produits = aucun changement
- Bump service worker CACHE_NAME v12 -> v13"

git push origin main

echo "=== Termine ==="
