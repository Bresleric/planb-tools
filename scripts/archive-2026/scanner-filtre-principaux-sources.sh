#!/usr/bin/env bash
# Fix UX scanner rafale : n envoyer au scanner que les MP a scanner
# (principaux OU sources de sous-produit). Exclut epices et accessoires.
# Usage : bash scripts/scanner-filtre-principaux-sources.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add taf/index.html production/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "fix(scan-fefo): ne scanner que les principaux et sources de sous-produit

Le scanner affichait TOUS les ingredients de la fiche (12 pour Choucroute Garnie),
laissant croire qu il fallait tout scanner alors que seuls les principaux et les
sources de sous-produit le sont.

- taf/index.html et production/index.html filtrent scan_fefo_context.ingredients
  sur (est_principal OR is_source_sous_produit) avant de pousser le contexte
- Les epices et accessoires ne sont plus envoyes au scanner
- Le scanner affiche ce qu il recoit : aucune modif necessaire de son cote
- Bump service worker CACHE_NAME v8 -> v9"

git push origin main

echo "=== Termine ==="
