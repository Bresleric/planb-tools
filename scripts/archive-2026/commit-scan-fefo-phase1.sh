#!/usr/bin/env bash
# Versionne la migration Phase 1 du projet Scan-FEFO.
# Migration purement additive, à appliquer ensuite dans Supabase Studio.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/2026-05-14_fiche_ingredients_est_principal.sql
git commit -m "chore: scan-fefo phase 1 — fiche_ingredients.est_principal

Première étape du workflow 'Scanner l'étiquette du produit principal au
démarrage du TAF + sortie de stock automatique + alerte FEFO strict'.

scripts/migrations/2026-05-14_fiche_ingredients_est_principal.sql :
- ADD COLUMN est_principal BOOLEAN NOT NULL DEFAULT false
- Index partiel sur fiche_id WHERE est_principal = true

Migration 100% additive : tant qu'aucun ingrédient n'est marqué
principal, le comportement actuel des fiches est conservé. Phase 2
ajoutera l'UI Admin pour cocher 'Principal' sur les ingrédients qui
doivent être scannés (typiquement les matières coûteuses/critiques)."

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer la migration dans Supabase Studio :"
echo "  SQL Editor → New query → coller le contenu de :"
echo "    ~/planb-tools/scripts/migrations/2026-05-14_fiche_ingredients_est_principal.sql"
echo "  Run."
