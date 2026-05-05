#!/bin/bash
# =============================================================================
# Deploiement combine Stock + Production (rattachement articles inclus)
# =============================================================================
# Usage : bash scripts/deploy-prod-stock.sh
# =============================================================================

set -e

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"
LOCAL_DIR="$HOME/planb-tools"

cd "$LOCAL_DIR"

echo "==> Sync iCloud -> ~/planb-tools/"
cp -r "$ICLOUD_DIR/stock"      "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/scanner"    "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/production" "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/taf"        "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/supabase"   "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/scripts"    "$LOCAL_DIR/" 2>/dev/null || true
cp    "$ICLOUD_DIR/index.html"  "$LOCAL_DIR/"

echo "==> git status"
git status --short

echo ""
echo "==> git add + commit + push"
git add stock/ scanner/ production/ taf/ supabase/ scripts/ index.html 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "feat(production): consommation auto matieres premieres au demarrage tache"
  git push
  echo ""
  echo "==> Pousse OK. GitHub Pages va redeployer en ~1 minute."
else
  echo "Rien a committer."
fi
