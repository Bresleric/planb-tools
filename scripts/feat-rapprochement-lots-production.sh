#!/usr/bin/env bash
# Versionne les fichiers de TRACE du sous-module "Lots et rapprochement stock".
#
# IMPORTANT : le CODE applicatif (production/index.html + bump sw.js) a deja ete
# capture et pousse par le commit a8d0c86 (acteur concurrent, message recycle
# "impression etiquette 3 taps"). La migration BDD est deja appliquee via MCP.
# Ce script ne committe donc QUE la trace migration SQL + ce script lui-meme,
# sans toucher aux modifs concurrentes en cours (briefing/index.html, index.html).

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche active : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

# Ajout cible : uniquement les fichiers de trace de cette feature.
git add migration_rapprochement_lots.sql scripts/feat-rapprochement-lots-production.sh

echo "=== Fichiers a committer ==="
git status --short -- migration_rapprochement_lots.sql scripts/feat-rapprochement-lots-production.sh
echo

git commit -m "chore(production): trace migration sous-module Lots et rapprochement stock

Le code applicatif (production/index.html bloc window.RAP + bump sw.js v18) a
deja ete pousse par le commit a8d0c86. La migration BDD (production_rapprochements,
rapprochement_apprentissage, colonnes audit reouverture sur productions, RLS anon
FOR ALL + index) a deja ete appliquee via MCP le 05/06/2026.

Ce commit ajoute uniquement la trace SQL idempotente de cette migration."

git push origin "$BRANCH"
echo
echo "=== Push effectue sur $BRANCH ==="
