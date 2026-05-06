#!/bin/bash
# =============================================================================
# Deploiement du module Information (journal d'entreprise + suivi de lecture)
# =============================================================================
# Usage : bash scripts/deploy-information.sh
# Sync iCloud -> ~/planb-tools/, puis git add/commit/push.
# Inclut : information/, index.html racine (entree de menu + badge non-lus).
# =============================================================================

set -e

ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/Claude/Projects/PlanB-Tools"
LOCAL_DIR="$HOME/planb-tools"

cd "$LOCAL_DIR"

echo "==> Sync iCloud -> ~/planb-tools/"
cp -r "$ICLOUD_DIR/information" "$LOCAL_DIR/" 2>/dev/null || true
cp    "$ICLOUD_DIR/index.html"  "$LOCAL_DIR/" 2>/dev/null || true
cp    "$ICLOUD_DIR/scripts/deploy-information.sh" "$LOCAL_DIR/scripts/" 2>/dev/null || true

echo "==> git status"
git status --short

echo ""
echo "==> git add + commit + push"
git add information/ index.html scripts/deploy-information.sh 2>/dev/null || true
if ! git diff --cached --quiet; then
  git commit -m "feat(information): module journal d'entreprise + suivi de lecture par user"
  git push
  echo ""
  echo "==> Pousse OK. GitHub Pages va redeployer en ~1 minute."
else
  echo "Rien a committer."
fi

echo ""
echo "============================================================"
echo "  ETAPES MANUELLES SUPABASE (a faire UNE FOIS)"
echo "============================================================"
echo "  1. Executer le schema SQL dans Supabase Studio :"
echo "     -> information/schema.sql (tables + RPC)"
echo ""
echo "  2. Creer les buckets Storage dans Supabase Studio :"
echo "     -> Bucket 'information-images'      (PUBLIC, max 5 Mo)"
echo "     -> Bucket 'information-attachments' (PRIVE,  max 20 Mo)"
echo ""
echo "  3. Acces module :"
echo "     -> https://bresleric.github.io/planb-tools/information/"
echo "============================================================"
