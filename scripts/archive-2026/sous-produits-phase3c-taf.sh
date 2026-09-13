#!/usr/bin/env bash
# Phase 3 (c) : validation production TAF avec sous-produits (mere + N filles).
# Portage de la mecanique du commit (b) cote taf/index.html (saveProductionFromTaf).
# Usage : bash scripts/sous-produits-phase3c-taf.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add taf/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "feat(taf): Phase 3c validation production multi sous-produits

Porte la mecanique sous-produits du module Production vers le TAF.
Si la fiche declare des sous-produits, la validation cree N etiquettes.
Mono inchange (fiche sans sous-produits ou nouveau produit).

- Helpers dupliques (pas de JS partage) : tafGetSousProduits (cache),
  tafComputeSousProduitQtys (somme poids_net_kg scannes x ratio), tafRender,
  tafApplyMultiMode, tafSetupSousProduits
- UI : section Sous-produits a etiqueter dans la modale TAF ; en multi on masque
  qty/DLC globaux ; cablee sur ouverture modale, choix de fiche, nouveau produit,
  fermeture (reset)
- saveProductionFromTaf : isMulti calcule avant validation (quantite globale non
  requise en multi) ; cree 1 mere (qty 1, unite production, DLC la plus longue
  des filles) + N filles (parent_production_id, qty/unite/DLC propres). Sorties
  stock + cloture de la task TAF sur la mere uniquement
- Redirection vers production?prod_id=MERE&action=etiquette&return=taf inchangee
  -> handler commit a detecte les filles -> PDF N pages
- Bump service worker CACHE_NAME v14 -> v15"

git push origin main

echo "=== Termine ==="
