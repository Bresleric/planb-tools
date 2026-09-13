#!/usr/bin/env bash
# Phase 3 (a) : fondation PDF multi-pages sous-produits + handler prod_id&action=etiquette.
# Usage : bash scripts/sous-produits-phase3a-pdf-multi.sh
set -e

cd ~/planb-tools

echo "=== Branche active ==="
git branch --show-current

git add production/index.html sw.js

echo "=== Diff resume ==="
git status --short

git commit -m "feat(production): Phase 3a etiquettes multi-pages sous-produits

Fondation pour generer N etiquettes a la validation d une production qui
declare des sous-produits. Mono-produit strictement inchange (ajout pur).

- buildEtiquettePdfData : extrait les donnees d etiquette d une production
- printEtiquettesMulti : genere un PDF N pages (1 etiquette 62x89 par fille,
  meme layout que le mono) ouvert dans Safari pour partage Brother iPrint&Label
- handleEtiquetteParam : handler du retour TAF (?prod_id=X&action=etiquette).
  Si la production a des filles -> PDF multi, sinon etiquette mono.
  Implemente aussi le retour TAF mono qui n etait pas gere.
- getProductions filtre parent_production_id IS NULL : les filles n apparaissent
  pas dans la liste principale (decision B)
- Bump service worker CACHE_NAME v9 -> v10"

git push origin main

echo "=== Termine ==="
