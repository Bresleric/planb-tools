#!/bin/bash
# =============================================================================
# Déploiement de l'Edge Function extract-document
# =============================================================================
# Usage : bash scripts/deploy-extract-document.sh
# Pré-requis :
#   - être dans ~/planb-tools/ (le repo git)
#   - supabase CLI installée et liée au projet (supabase link une fois)
# =============================================================================

set -e   # arrêt immédiat sur erreur

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"
LOCAL_DIR="$HOME/planb-tools"

cd "$LOCAL_DIR"

echo "==> Sync iCloud -> ~/planb-tools/"
cp -r "$ICLOUD_DIR/supabase" "$LOCAL_DIR/"
cp -r "$ICLOUD_DIR/scanner"  "$LOCAL_DIR/" 2>/dev/null || true
cp -r "$ICLOUD_DIR/scripts"  "$LOCAL_DIR/" 2>/dev/null || true

echo "==> git status"
git status --short

echo ""
echo "==> git add + commit + push"
git add supabase/ scanner/ scripts/ 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "feat(scanner): Phase 1 - Edge Function extract-document (Claude Vision)"
  git push
else
  echo "Rien a committer."
fi

echo ""
echo "==> supabase --version"
supabase --version

echo ""
echo "==> Deploiement de la function extract-document"
supabase functions deploy extract-document

echo ""
echo "==> Termine. La function est deployee."
echo "    Endpoint : https://<PROJECT-REF>.supabase.co/functions/v1/extract-document"
