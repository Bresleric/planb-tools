#!/usr/bin/env bash
# Nettoyage final : versionne tout ce qui traîne en untracked
# (.gitignore, scripts/commit-*.sh, scripts DEPLOY/REVERT, Excel mapping)
# et ignore .claude/ via le .gitignore.

set -euo pipefail
cd ~/planb-tools

BRANCH=$(git branch --show-current)
echo "=== Branche : $BRANCH ==="

rm -f .git/index.lock 2>/dev/null || true

echo
echo "=== Avant : git status ==="
git status --short
echo

echo "=== Add ==="
# Tout sauf .claude/ (ignoré via .gitignore)
git add .gitignore
git add scripts/commit-*.sh
git add scripts/migrations/
[ -f DEPLOY-DROITS-TABS.sh ] && git add DEPLOY-DROITS-TABS.sh || true
[ -f DEPLOY-DROITS-V2.sh ] && git add DEPLOY-DROITS-V2.sh || true
[ -f REVERT-TAF.sh ] && git add REVERT-TAF.sh || true
[ -f Mapping_Produit_Action.xlsx ] && git add Mapping_Produit_Action.xlsx || true

echo
echo "=== git status après add ==="
git status --short
echo

echo "=== Commit ==="
git commit -m "chore: versionnement final scripts + Excel + .gitignore

- .gitignore complété (ajout .claude/ — config locale Claude Code)
- 13 scripts/commit-*.sh accumulés depuis le 8/5 (historique des
  opérations Cowork, permettent de relancer)
- 2 scripts DEPLOY-DROITS-*.sh d'Eric (gestion droits onglets)
- 1 script REVERT-TAF.sh d'Eric (script de récupération)
- scripts/migrations/ versionné (SQL Supabase à appliquer)
- Mapping_Produit_Action.xlsx (proposition de décomposition
  produit/action des 137 predefined_tasks, à valider par Eric)

git status devrait être propre après ce commit."

git push origin "$BRANCH"

echo
echo "=== git status final ==="
git status --short

echo
echo "=== Terminé ✓ ==="
