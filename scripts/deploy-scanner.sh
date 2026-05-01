#!/bin/bash
# =============================================================================
# Deploiement du module Scanner (Phase 2)
# =============================================================================
# Usage : bash scripts/deploy-scanner.sh
# Sync iCloud -> ~/planb-tools/, puis git add/commit/push.
# Inclut : scanner/index.html, supabase/functions/extract-document/, et
# index.html racine (avec la nouvelle entree Scanner dans MODULES).
# =============================================================================

set -e

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"
LOCAL_DIR="$HOME/planb-tools"

cd "$LOCAL_DIR"

echo "==> Sync iCloud -> ~/planb-tools/"
cp -r "$ICLOUD_DIR/scanner"   "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/supabase"  "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/scripts"   "$LOCAL_DIR/" 2>/dev/null || true
cp    "$ICLOUD_DIR/index.html" "$LOCAL_DIR/"

echo "==> git status"
git status --short

echo ""
echo "==> git add + commit + push"
git add scanner/ supabase/ scripts/ index.html 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "feat(scanner): Phase 2 - interface utilisateur scanner/index.html + ajout au portail"
  git push
  echo ""
  echo "==> Pousse OK. GitHub Pages va redeployer en ~1 minute."
  echo "    URL : https://bresleric.github.io/planb-tools/"
else
  echo "Rien a committer."
fi
