#!/usr/bin/env bash
# Versionne la migration V2 du backfill est_principal (corrigée).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

git status --short
echo

git add scripts/migrations/2026-05-14_backfill_est_principal_v2_appro_ingredients.sql
git commit -m "fix(scan-fefo): backfill V2 — bonne table appro_ingredients

La migration V1 (2026-05-14_backfill_est_principal_carnes_laitiers.sql)
joignait fiche_ingredients.article_id sur appro_catalogue. Mais
article_id pointe en réalité vers appro_ingredients (366 lignes,
table dédiée). Résultat V1 : 0 ligne affectée.

V2 corrigée :
- Cible appro_ingredients (la bonne table)
- Catégories ciblées :
    * Viande & charcuterie (26 articles)
    * Poisson (1)
    * Frais (18) avec mots-clés carnés/laitiers
    * Surgelés (4) avec mots-clés carnés
    * Oeufs (3) — catégorie dédiée dans appro_ingredients
- Mots-clés laitiers : œufs/oeuf retirés (couverts par catégorie Oeufs)

Idempotent (UPDATE WHERE est_principal = false). Peut être appliquée
sans craindre le double effet de la V1 (qui n'a rien fait)."

git push origin "$BRANCH"

echo
echo "=== Terminé ✓ ==="
echo
echo "PROCHAINE ÉTAPE — appliquer dans Supabase Studio :"
echo "  SQL Editor → New query → coller :"
echo "    ~/planb-tools/scripts/migrations/2026-05-14_backfill_est_principal_v2_appro_ingredients.sql"
echo "  Run."
